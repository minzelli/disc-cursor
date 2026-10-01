Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    $platform_error = 'Host platform is not Windows. Run script on Windows.'
    throw [System.PlatformNotSupportedException]::new($platform_error)
}

$current_identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $is_system_session = $current_identity.IsSystem
}
finally {
    $current_identity.Dispose()
}

if ($is_system_session) {
    $session_error = 'NT AUTHORITY\SYSTEM session denies execution. ' +
        'Run in an interactive user session.'
    throw [System.InvalidOperationException]::new($session_error)
}

$SCHEME_NAME = 'Disc'
$REGISTRY_ROOT_PATH = 'HKCU:\Control Panel\Cursors'
$REGISTRY_SCHEMES_PATH = 'HKCU:\Control Panel\Cursors\Schemes'

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

    Remove-ItemProperty -LiteralPath $REGISTRY_SCHEMES_PATH `
        -Name $scheme_name `
        -ErrorAction SilentlyContinue
}

function purge_target_directory {
    param(
        [string]$target_directory,
        [string]$expected_root
    )

    if ([string]::IsNullOrWhiteSpace($target_directory)) {
        $empty_target_error = 'Target directory parameter is empty. ' +
            'Provide a valid path.'
        throw [System.ArgumentException]::new($empty_target_error)
    }

    $canonical_target = [System.IO.Path]::GetFullPath($target_directory)
    $canonical_root = [System.IO.Path]::GetFullPath($expected_root)

    $is_within_root = $canonical_target.StartsWith(
        $canonical_root,
        [System.StringComparison]::OrdinalIgnoreCase
    )
    if (-not $is_within_root) {
        $root_error = "Target path '$canonical_target' falls outside " +
            'allowed root. Verify directory scope.'
        throw [System.ArgumentException]::new($root_error)
    }

    $is_valid_scheme = $canonical_target.EndsWith(
        'Disc_Cursor_Scheme\cursor',
        [System.StringComparison]::OrdinalIgnoreCase
    )
    if (-not $is_valid_scheme) {
        $scheme_error = "Target path '$canonical_target' does not match " +
            'expected scheme. Verify scheme directory.'
        throw [System.ArgumentException]::new($scheme_error)
    }

    if (-not (Test-Path -LiteralPath $canonical_target)) {
        $missing_warning = "Target cursor directory '$canonical_target' " +
            'does not exist. Verify application data directory.'
        Write-Warning -Message $missing_warning
        return
    }

    $target_item = Get-Item -LiteralPath $canonical_target -Force
    $is_reparse_point = [bool](
        $target_item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
    )

    if ($is_reparse_point) {
        Remove-Item -LiteralPath $canonical_target -Force
    }
    else {
        Remove-Item -LiteralPath $canonical_target -Recurse -Force
    }

    $parent_directory = Split-Path -Parent $canonical_target
    $is_scheme_parent = $parent_directory.EndsWith(
        'Disc_Cursor_Scheme',
        [System.StringComparison]::OrdinalIgnoreCase
    )

    if ((Test-Path -LiteralPath $parent_directory) -and $is_scheme_parent) {
        try {
            $has_remaining_files = [bool](Get-ChildItem -LiteralPath $parent_directory `
                -Force -ErrorAction Stop | Select-Object -First 1)
            if (-not $has_remaining_files) {
                Remove-Item -LiteralPath $parent_directory -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            $lock_warning = 'File lock prevents parent directory removal. ' +
                'Verify remaining files.'
            Write-Warning -Message $lock_warning
        }
    }
}

function broadcast_removal_notification {
    param()

    $type_name = 'Cursor_Native_Notifier'
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
        uint action_identifier,
        uint parameter_first,
        System.IntPtr parameter_second,
        uint update_flags
    );
'@

        try {
            $native_reloader = Add-Type -MemberDefinition $signature_definition `
                -Name $type_name `
                -Namespace 'Disc_Cursor_Scheme' `
                -PassThru
        }
        catch {
            $policy_warning = 'System policy restricts live shell reload. ' +
                'Sign out or reload desktop session to apply changes.'
            Write-Warning -Message $policy_warning
            return
        }
    }

    $SPI_SETCURSORS = 0x0057
    $SPIF_SENDCHANGE = 0x0002
    $update_flags = $SPIF_SENDCHANGE

    $has_broadcast = $native_reloader::SystemParametersInfo(
        $SPI_SETCURSORS,
        0,
        [System.IntPtr]::Zero,
        $update_flags
    )

    if (-not $has_broadcast) {
        $error_code = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $failure_warning = 'Shell cursor update fails with Win32 error code ' +
            "$error_code. Sign out or reload desktop session to apply changes."
        Write-Warning -Message $failure_warning
    }
}

function execute_uninstallation {
    param(
        [string]$target_directory,
        [string]$expected_root
    )

    $standard_roles = collected_standard_roles

    delete_scheme_entry -scheme_name $SCHEME_NAME

    restore_standard_cursors -role_names $standard_roles

    purge_target_directory `
        -target_directory $target_directory `
        -expected_root $expected_root

    broadcast_removal_notification
}

$local_data_directory = $env:LOCALAPPDATA
if (-not $local_data_directory) {
    $folder_type = [System.Environment+SpecialFolder]::LocalApplicationData
    $local_data_directory = [System.Environment]::GetFolderPath($folder_type)
}

if ([string]::IsNullOrWhiteSpace($local_data_directory)) {
    $directory_error = 'LocalApplicationData path does not exist. ' +
        'Set LOCALAPPDATA environment variable.'
    throw [System.IO.DirectoryNotFoundException]::new($directory_error)
}

$cursor_target_directory = Join-Path -Path $local_data_directory `
    -ChildPath 'Disc_Cursor_Scheme\cursor'

execute_uninstallation `
    -target_directory $cursor_target_directory `
    -expected_root $local_data_directory