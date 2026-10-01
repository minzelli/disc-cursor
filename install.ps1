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

class Cursor_Asset_Descriptor {
    [string]$role_name
    [string]$file_name

    Cursor_Asset_Descriptor([string]$role_identifier, [string]$file_identifier) {
        $this.role_name = $role_identifier
        $this.file_name = $file_identifier
    }
}

function generated_cursor_inventory {
    [OutputType([Cursor_Asset_Descriptor[]])]
    param()

    $cursor_descriptors = @(
        [Cursor_Asset_Descriptor]::new('Arrow', 'disc-normal.cur')
        [Cursor_Asset_Descriptor]::new('Help', 'disc-help.cur')
        [Cursor_Asset_Descriptor]::new('AppStarting', 'disc-working.ani')
        [Cursor_Asset_Descriptor]::new('Wait', 'disc-busy.ani')
        [Cursor_Asset_Descriptor]::new('Crosshair', 'disc-precision.cur')
        [Cursor_Asset_Descriptor]::new('IBeam', 'disc-text.cur')
        [Cursor_Asset_Descriptor]::new('NWPen', 'disc-handwriting.cur')
        [Cursor_Asset_Descriptor]::new('No', 'disc-unavailable.cur')
        [Cursor_Asset_Descriptor]::new('SizeNS', 'disc-vertical.cur')
        [Cursor_Asset_Descriptor]::new('SizeWE', 'disc-horizontal.cur')
        [Cursor_Asset_Descriptor]::new('SizeNWSE', 'disc-diagonal1.cur')
        [Cursor_Asset_Descriptor]::new('SizeNESW', 'disc-diagonal2.cur')
        [Cursor_Asset_Descriptor]::new('SizeAll', 'disc-move.cur')
        [Cursor_Asset_Descriptor]::new('UpArrow', 'disc-alternate.cur')
        [Cursor_Asset_Descriptor]::new('Hand', 'disc-link.cur')
        [Cursor_Asset_Descriptor]::new('Person', 'disc-person.cur')
        [Cursor_Asset_Descriptor]::new('Pin', 'disc-location.cur')
    )

    return , $cursor_descriptors
}

function verify_source_inventory {
    param(
        [string]$source_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    $is_source_present = Test-Path -LiteralPath $source_directory
    if (-not $is_source_present) {
        $source_error = "Source directory '$source_directory' " +
            'does not exist. Provide a valid directory.'
        throw [System.IO.DirectoryNotFoundException]::new($source_error)
    }

    foreach ($item in $inventory) {
        $file_path = Join-Path -Path $source_directory `
            -ChildPath $item.file_name
        $is_file_present = Test-Path -LiteralPath $file_path
        if (-not $is_file_present) {
            $missing_error = "Cursor asset '$($item.file_name)' " +
                'does not exist. Verify asset integrity.'
            throw [System.IO.FileNotFoundException]::new($missing_error)
        }

        $file_stream = [System.IO.File]::OpenRead($file_path)
        try {
            if ($file_stream.Length -le 0) {
                $empty_error = "Cursor asset '$($item.file_name)' is empty. " +
                    'Provide a valid cursor asset.'
                throw [System.IO.InvalidDataException]::new($empty_error)
            }

            $header_bytes = [byte[]]::new(4)
            $null = $file_stream.Read($header_bytes, 0, 4)
        }
        finally {
            $file_stream.Dispose()
        }

        $is_cur = ($header_bytes[0] -eq 0x00 -and
            $header_bytes[1] -eq 0x00 -and
            $header_bytes[2] -eq 0x02 -and
            $header_bytes[3] -eq 0x00)
        $is_ani = ($header_bytes[0] -eq 0x52 -and
            $header_bytes[1] -eq 0x49 -and
            $header_bytes[2] -eq 0x46 -and
            $header_bytes[3] -eq 0x46)

        if ((-not $is_cur) -and (-not $is_ani)) {
            $header_error = "Cursor asset '$($item.file_name)' contains an " +
                'unrecognized header. Verify asset integrity.'
            throw [System.IO.InvalidDataException]::new($header_error)
        }
    }
}

function create_target_directory {
    param([string]$target_directory)

    $canonical_path = [System.IO.Path]::GetFullPath($target_directory)
    if ($canonical_path.Contains(',')) {
        $comma_error = "Target path '$canonical_path' contains a comma " +
            'delimiter. Specify path without commas.'
        throw [System.ArgumentException]::new($comma_error)
    }

    $null = New-Item -Path $canonical_path `
        -ItemType Directory `
        -Force
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
        Copy-Item -LiteralPath $source_file `
            -Destination $target_directory `
            -Force
    }
}

function resolved_scheme_payload {
    param(
        [string]$target_directory,
        [Cursor_Asset_Descriptor[]]$inventory
    )

    $canonical_target = [System.IO.Path]::GetFullPath($target_directory)
    if ($canonical_target.Contains(',')) {
        $comma_error = "Target path '$canonical_target' contains a comma " +
            'delimiter. Specify path without commas.'
        throw [System.ArgumentException]::new($comma_error)
    }

    $standard_roles = @(
        'Arrow', 'Help', 'AppStarting', 'Wait',
        'Crosshair', 'IBeam', 'NWPen', 'No',
        'SizeNS', 'SizeWE', 'SizeNWSE', 'SizeNESW',
        'SizeAll', 'UpArrow', 'Hand', 'Person', 'Pin'
    )

    $files_by_role = @{}
    foreach ($item in $inventory) {
        $files_by_role[$item.role_name] = $item.file_name
    }

    $ordered_paths = [System.Collections.Generic.List[string]]::new()
    foreach ($role in $standard_roles) {
        $file_name = $files_by_role[$role]
        $resolved_path = Join-Path -Path $canonical_target `
            -ChildPath $file_name
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

    $null = New-Item -Path $REGISTRY_SCHEMES_PATH -Force

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

    $type_name = 'Cursor_Native_Notifier'
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
        System.IntPtr parameter_second,
        uint update_flags
    );
'@

        try {
            $native_type = Add-Type -MemberDefinition $signature_definition `
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

    $has_broadcast = $native_type::SystemParametersInfo(
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

function execute_installation {
    param(
        [string]$source_directory,
        [string]$target_directory
    )

    $canonical_source = [System.IO.Path]::GetFullPath($source_directory)
    $canonical_target = [System.IO.Path]::GetFullPath($target_directory)

    $cursor_inventory = generated_cursor_inventory

    verify_source_inventory `
        -source_directory $canonical_source `
        -inventory $cursor_inventory

    create_target_directory -target_directory $canonical_target

    copy_cursor_catalog `
        -source_directory $canonical_source `
        -target_directory $canonical_target `
        -inventory $cursor_inventory

    $scheme_payload = resolved_scheme_payload `
        -target_directory $canonical_target `
        -inventory $cursor_inventory

    register_cursor_scheme `
        -scheme_name $SCHEME_NAME `
        -scheme_payload $scheme_payload `
        -target_directory $canonical_target `
        -inventory $cursor_inventory

    notify_system_shell
}

$cursor_source_directory = Join-Path -Path $PSScriptRoot `
    -ChildPath 'cursor'

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

execute_installation `
    -source_directory $cursor_source_directory `
    -target_directory $cursor_target_directory