# ============================================================
# CHANGE COMPUTER NAME (EMBEDDED RUNSPACE COMPATIBLE)
# ============================================================

[CmdletBinding()]
param(
    # New NetBIOS name for the local computer (1-15 alphanumeric/hyphen characters)
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$NewName,

    # Optional parameter to force reboot after successful rename
    [Parameter(Mandatory = $false)]
    [switch]$Restart
)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Test-IsAdministrator {
    <#
        .SYNOPSIS
        Checks if the current process running context has elevated administrative privileges.
        Why: Prevents invoking privileged execution commands when UAC elevation is absent,
        returning output directly to the streams rather than spawning unwanted secondary windows.
    #>
    $Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]$Identity
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
# EXECUTION PIPELINE
# ============================================================

Write-Output "============================================================"
Write-Output "               Change Computer Name Utility                 "
Write-Output "============================================================"

# Verify administrative context
if (-not (Test-IsAdministrator)) {
    Write-Error "[!] Administrator privileges are required to rename this computer."
    Write-Warning "[!] Please launch the main Admin Toolkit application with elevated rights (Run as Administrator)."
    return
}

$CurrentName = $env:COMPUTERNAME
Write-Output "[>] Current Computer Name: $CurrentName"

# Handle missing parameter by logging instructions
if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Warning "[!] No new computer name was specified."
    Write-Output "------------------------------------------------------------"
    Write-Output " Usage Example (Run in command box below):"
    Write-Output "   .\ChangeName.ps1 -NewName 'SERVER-01'"
    Write-Output "   .\ChangeName.ps1 -NewName 'SERVER-01' -Restart"
    Write-Output "------------------------------------------------------------"
    return
}

# Sanitize inputs
$CleanName = $NewName.Trim()

# Validate against RFC 1123 / NetBIOS constraints
if ($CleanName.Length -gt 15) {
    Write-Error "[-] Computer names cannot exceed 15 characters in length."
    return
}

# Regex Ensures: Starts/Ends with Alphanumeric, Hyphens allowed in middle only
if ($CleanName -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,13}[a-zA-Z0-9])?$') {
    Write-Error "[-] Invalid computer name format: '$CleanName'."
    Write-Warning "[!] Names must contain only letters, numbers, and hyphens (cannot start or end with a hyphen)."
    return
}

if ($CleanName.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "[!] Target name '$CleanName' is identical to the current computer name."
    return
}

# Execution Action
Write-Output "[>] Attempting to rename computer: $CurrentName -> $CleanName"

try {
    Rename-Computer -NewName $CleanName -Force -ErrorAction Stop
    
    Write-Output "[+] Computer name successfully changed to '$CleanName'."
    Write-Warning "[!] A system restart is required for changes to take full effect."

    if ($Restart) {
        Write-Warning "[!] -Restart switch detected. Initiating system restart in 5 seconds..."
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
    else {
        Write-Output "[>] To restart later, execute 'Restart-Computer' or use your administrative controls."
    }
}
catch {
    Write-Error "[-] Failed to rename computer '$CurrentName'."
    Write-Error "[-] Exception: $($_.Exception.Message)"
}
