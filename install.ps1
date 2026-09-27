Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw [System.PlatformNotSupportedException]::new('This script is only supported on Windows operating systems.')
}

$SCHEME_NAME = 'Disc'
$REGISTRY_ROOT_PATH = 'HKCU:\Control Panel\Cursors'
$REGISTRY_SCHEMES_PATH = 'HKCU:\Control Panel\Cursors\Schemes'

class Cursor_Asset_Descriptor {
    [string]$role_name
    [string]$file_name

    Cursor_Asset_Descriptor(
        [string]$role_identifier,
        [string]$file_identifier
    ) {
        $this.role_name = $role_identifier
        $this.file_name = $file_identifier
    }
}

function generated_cursor_inventory {
    [OutputType([Cursor_Asset_Descriptor[]])]
    param()

    $cursor_descriptors = [System.Collections.Generic.List[Cursor_Asset_Descriptor]]::new()

    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Arrow', 'disc-normal.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Help', 'disc-help.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('AppStarting', 'disc-working.ani')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Wait', 'disc-busy.ani')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Crosshair', 'disc-precision.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('IBeam', 'disc-text.cur')
    )

    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('NWPen', 'disc-handwriting.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('No', 'disc-unavailable.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('SizeNS', 'disc-vertical.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('SizeWE', 'disc-horizontal.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('SizeNWSE', 'disc-diagonal1.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('SizeNESW', 'disc-diagonal2.cur')
    )

    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('SizeAll', 'disc-move.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('UpArrow', 'disc-alternate.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Hand', 'disc-link.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Person', 'disc-person.cur')
    )
    $cursor_descriptors.Add(
        [Cursor_Asset_Descriptor]::new('Pin', 'disc-location.cur')
    )

    return , $cursor_descriptors.ToArray()
}

function verifies_source_inventory {
    param(
        [string]$source_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    $is_source_present = Test-Path -LiteralPath $source_directory
    if (-not $is_source_present) {
        throw [System.IO.DirectoryNotFoundException]::new("Source directory does not exist: '$source_directory'. Provide a valid directory containing cursor assets.")
    }

    foreach ($item in $inventory) {
        $file_path = Join-Path -Path $source_directory `
            -ChildPath $item.file_name
        $is_file_present = Test-Path -LiteralPath $file_path
        if (-not $is_file_present) {
            throw [System.IO.FileNotFoundException]::new("Cursor asset does not exist: '$($item.file_name)'. Verify asset integrity within source repository.")
        }
    }

    return $true
}

function create_target_directory {
    param([string]$target_directory)

    $is_target_present = Test-Path -LiteralPath $target_directory
    if (-not $is_target_present) {
        New-Item -Path $target_directory `
            -ItemType Directory `
            -Force | Out-Null
    }

    $is_created = Test-Path -LiteralPath $target_directory
    if (-not $is_created) {
        throw [System.IO.IOException]::new("Target directory creation failed: '$target_directory'. Grant write permissions to local application data.")
    }
}

function copy_cursor_catalog {
    param(
        [string]$source_directory,
        [string]$target_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    foreach ($item in $inventory) {
        $source_file = Join-Path -Path $source_directory `
            -ChildPath $item.file_name
        $target_file = Join-Path -Path $target_directory `
            -ChildPath $item.file_name
        Copy-Item -LiteralPath $source_file `
            -Destination $target_file `
            -Force
    }
}

function resolved_scheme_payload {
    param(
        [string]$target_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    $standard_roles = @(
        'Arrow', 'Help', 'AppStarting', 'Wait',
        'Crosshair', 'IBeam', 'NWPen', 'No',
        'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW',
        'SizeAll', 'UpArrow', 'Hand', 'Person', 'Pin'
    )

    $ordered_paths = [System.Collections.Generic.List[string]]::new()
    foreach ($role in $standard_roles) {
        $matched_descriptor = $inventory |
        Where-Object { $_.role_name -eq $role }
        $resolved_path = Join-Path -Path $target_directory `
            -ChildPath $matched_descriptor.file_name
        $ordered_paths.Add($resolved_path)
    }

    return ($ordered_paths -join ',')
}

function register_cursor_scheme {
    param(
        [string]$scheme_name,
        [string]$scheme_payload,
        [string]$target_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    $has_schemes_key = Test-Path -LiteralPath $REGISTRY_SCHEMES_PATH
    if (-not $has_schemes_key) {
        New-Item -Path $REGISTRY_SCHEMES_PATH -Force | Out-Null
    }

    Set-ItemProperty -LiteralPath $REGISTRY_SCHEMES_PATH `
        -Name $scheme_name `
        -Value $scheme_payload

    foreach ($item in $inventory) {
        $target_path = Join-Path -Path $target_directory `
            -ChildPath $item.file_name
        Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
            -Name $item.role_name `
            -Value $target_path
    }

    Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
        -Name '(Default)' `
        -Value $scheme_name

    Set-ItemProperty -LiteralPath $REGISTRY_ROOT_PATH `
        -Name 'Scheme Source' `
        -Value 1 `
        -Type DWord
}

function notify_system_shell {
    param()

    $type_name = 'Installer_Cursor_Notifier'
    $full_type_name = "Disc_Cursor_Scheme.$type_name"
    $native_type = $full_type_name -as [type]

    if (-not $native_type) {
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
        string parameter_second,
        uint update_flags
    );
'@

        $native_type = Add-Type -MemberDefinition $signature_definition `
            -Name $type_name `
            -Namespace 'Disc_Cursor_Scheme' `
            -PassThru
    }

    $SPI_SETCURSORS = 0x0057
    $SPIF_UPDATEINIFILE = 0x0001
    $SPIF_SENDCHANGE = 0x0002
    $update_flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE

    $has_broadcast = $native_type::SystemParametersInfo(
        $SPI_SETCURSORS,
        0,
        [string]::Empty,
        $update_flags
    )

    if (-not $has_broadcast) {
        Write-Warning -Message "System parameters update failed. Log out or reload desktop session to apply changes."
    }
}

function execute_installation {
    param(
        [string]$source_directory,
        [string]$target_directory
    )

    $cursor_inventory = generated_cursor_inventory

    verifies_source_inventory `
        -source_directory $source_directory `
        -inventory $cursor_inventory | Out-Null

    create_target_directory -target_directory $target_directory

    copy_cursor_catalog `
        -source_directory $source_directory `
        -target_directory $target_directory `
        -inventory $cursor_inventory

    $scheme_payload = resolved_scheme_payload `
        -target_directory $target_directory `
        -inventory $cursor_inventory

    register_cursor_scheme `
        -scheme_name $SCHEME_NAME `
        -scheme_payload $scheme_payload `
        -target_directory $target_directory `
        -inventory $cursor_inventory

    notify_system_shell
}

$current_script_directory = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).ProviderPath
}

$cursor_source_directory = Join-Path -Path $current_script_directory `
    -ChildPath 'cursor'

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

execute_installation `
    -source_directory $cursor_source_directory `
    -target_directory $cursor_target_directory