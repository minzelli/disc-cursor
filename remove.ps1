Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw [System.PlatformNotSupportedException]::new('This script is only supported on Windows operating systems.')
}

$SCHEME_NAME = 'Disc'
$REGISTRY_ROOT_PATH = 'HKCU:\Control Panel\Cursors'
$REGISTRY_SCHEMES_PATH = 'HKCU:\Control Panel\Cursors\Schemes'

class Removal_Summary_State {
    [bool]$is_registry_cleared
    [bool]$is_directory_cleared

    Removal_Summary_State() {
        $this.is_registry_cleared = $false
        $this.is_directory_cleared = $false
    }
}

function collected_standard_roles {
    [OutputType([string[]])]
    param()

    $standard_roles = @(
        'Arrow', 'Help', 'AppStarting', 'Wait',
        'Crosshair', 'IBeam', 'NWPen', 'No',
        'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW',
        'SizeAll', 'UpArrow', 'Hand', 'Person', 'Pin'
    )

    return ,$standard_roles
}

function tests_scheme_registration {
    param([string]$scheme_name)

    $has_schemes_key = Test-Path -LiteralPath $REGISTRY_SCHEMES_PATH
    if (-not $has_schemes_key) {
        return $false
    }

    $scheme_properties = Get-ItemProperty -LiteralPath $REGISTRY_SCHEMES_PATH
    $is_present = [bool]($scheme_properties.PSObject.Properties[$scheme_name])

    return $is_present
}

function restore_standard_cursors {
    param([string[]]$role_names)

    if (Test-Path -LiteralPath $REGISTRY_ROOT_PATH) {
        foreach ($role in $role_names) {
            Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
                -Name $role `
                -Value ''
        }

        Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
            -Name '(Default)' `
            -Value 'Windows Default'

        Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
            -Name 'Scheme Source' `
            -Value 0 `
            -Type DWord
    }
}

function delete_scheme_entry {
    param([string]$scheme_name)

    $is_registered = tests_scheme_registration -scheme_name $scheme_name
    if ($is_registered) {
        Remove-ItemProperty -LiteralPath $REGISTRY_SCHEMES_PATH `
            -Name $scheme_name `
            -ErrorAction SilentlyContinue
    }
}

function purge_target_directory {
    param([string]$target_directory)

    if ([string]::IsNullOrWhiteSpace($target_directory)) {
        throw [System.ArgumentException]::new('Target directory parameter cannot be null or empty.')
    }

    $is_target_present = Test-Path -LiteralPath $target_directory
    if (-not $is_target_present) {
        Write-Warning -Message "Target cursor directory does not exist: '$target_directory'. Verify application data directory manually."
        return
    }

    Remove-Item -LiteralPath $target_directory `
        -Recurse `
        -Force

    $parent_directory = Split-Path -Parent $target_directory
    if ((Test-Path -LiteralPath $parent_directory) -and
        (@(Get-ChildItem -LiteralPath $parent_directory -Force).Count -eq 0)) {
        Remove-Item -LiteralPath $parent_directory -Force
    }
}

function broadcast_removal_notification {
    param()

    $type_name = 'Remover_Cursor_Notifier'
    $full_type_name = "Disc_Cursor_Scheme.$type_name"
    $native_reloader = $full_type_name -as [type]

    if (-not $native_reloader) {
        $signature_definition = @'
    [System.Runtime.InteropServices.DllImport(
        "user32.dll",
        EntryPoint = "SystemParametersInfoW",
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        SetLastError = true
    )]
    public static extern bool SystemParametersInfo(
        uint user_action,
        uint first_option,
        string string_option,
        uint change_notification
    );
'@

        $native_reloader = Add-Type -MemberDefinition $signature_definition `
            -Name $type_name `
            -Namespace 'Disc_Cursor_Scheme' `
            -PassThru
    }

    $SPI_SETCURSORS = 0x0057
    $SPIF_UPDATEINIFILE = 0x0001
    $SPIF_SENDCHANGE = 0x0002
    $update_flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE

    $has_broadcast = $native_reloader::SystemParametersInfo(
        $SPI_SETCURSORS,
        0,
        [string]::Empty,
        $update_flags
    )

    if (-not $has_broadcast) {
        Write-Warning -Message "Shell cursor refresh failed. Log out or restart system session to refresh cursors."
    }
}

function execute_uninstallation {
    param([string]$target_directory)

    $state = [Removal_Summary_State]::new()
    $standard_roles = collected_standard_roles

    delete_scheme_entry -scheme_name $SCHEME_NAME

    restore_standard_cursors -role_names $standard_roles
    $state.is_registry_cleared = $true

    purge_target_directory -target_directory $target_directory
    $state.is_directory_cleared = (-not (Test-Path -LiteralPath $target_directory))

    broadcast_removal_notification

    return $state
}

$local_data_directory = [System.Environment]::GetFolderPath(
    [System.Environment+SpecialFolder]::LocalApplicationData
)
if ([string]::IsNullOrWhiteSpace($local_data_directory)) {
    $local_data_directory = $env:LOCALAPPDATA
}
if ([string]::IsNullOrWhiteSpace($local_data_directory)) {
    throw [System.IO.DirectoryNotFoundException]::new('Unable to resolve LocalApplicationData directory.')
}

$cursor_target_directory = Join-Path -Path $local_data_directory `
    -ChildPath 'Disc_Cursor_Scheme\cursor'

execute_uninstallation -target_directory $cursor_target_directory | Out-Null