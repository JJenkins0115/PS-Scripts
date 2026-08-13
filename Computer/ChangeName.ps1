# ============================================================
# Script:        ChangeName.ps1
# Description:   Renames the local computer with robust validation.
# Compatibility: PowerShell 5.1+ / Core, Visual Studio Code, Embedded UI
# ============================================================

[CmdletBinding()]
param(
    # Target NetBIOS computer name (1-15 characters)
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$NewName,

    # Forces system restart immediately after successful rename
    [Parameter(Mandatory = $false)]
    [switch]$Restart
)

# Set strict execution standards for clean error tracing in VS Code
Set-StrictMode -Version 3.0

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Test-IsAdministrator {
    <#
        .SYNOPSIS
        Evaluates whether the current execution thread runs with elevated security rights.
        Why: Prevents invoking privileged registry/WMI operations when UAC elevation is absent.
    #>
    $Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]$Identity
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-InputModal {
    <#
        .SYNOPSIS
        Displays a self-contained modal prompt optimized for background task calls.
        Why: Replaces Read-Host and VisualBasic InputBox to prevent thread hanging in embedded UIs.
    #>
    param(
        [string]$PromptText,
        [string]$WindowTitle
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Form = New-Object System.Windows.Forms.Form -Property @{
        Text            = $WindowTitle
        Size            = New-Object System.Drawing.Size(400, 180)
        StartPosition   = 'CenterScreen'
        FormBorderStyle = 'FixedDialog'
        MaximizeBox     = $false
        MinimizeBox     = $false
        TopMost         = $true
    }

    $Label = New-Object System.Windows.Forms.Label -Property @{
        Location = New-Object System.Drawing.Point(15, 15)
        Size     = New-Object System.Drawing.Size(350, 30)
        Text     = $PromptText
    }

    $TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Location = New-Object System.Drawing.Point(15, 50)
        Size     = New-Object System.Drawing.Size(355, 25)
    }

    $OKButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Point(190, 90)
        Size         = New-Object System.Drawing.Size(85, 30)
        Text         = 'OK'
        DialogResult = [System.Windows.Forms.DialogResult]::OK
    }

    $CancelButton = New-Object System.Windows.Forms.Button -Property @{
        Location     = New-Object System.Drawing.Point(285, 90)
        Size         = New-Object System.Drawing.Size(85, 30)
        Text         = 'Cancel'
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }

    $Form.Controls.AddRange(@($Label, $TextBox, $OKButton, $CancelButton))
    $Form.AcceptButton = $OKButton
    $Form.CancelButton = $CancelButton

    # Activate form and keep it focused
    $Form.Add_Shown({ $Form.Activate(); $TextBox.Focus() })

    $Result = $Form.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $TextBox.Text
    }
    return $null
}

# ============================================================
# MAIN EXECUTION PIPELINE
# ============================================================

Write-Output "============================================================"
Write-Output "               Change Computer Name Utility                 "
Write-Output "============================================================"

# Privilege Verification
if (-not (Test-IsAdministrator)) {
    Write-Error "[!] Error: Administrator privileges are required."
    Write-Warning "[!] Relaunch the parent host application as Administrator."
    return
}

$CurrentName = $env:COMPUTERNAME
Write-Output "[>] Current Computer Name: $CurrentName"

# If parameter was not passed via CLI/UI invocation, trigger modal fallback
if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Output "[>] Requesting input via dialog..."
    $NewName = Show-InputModal -PromptText "Enter new name (Current: $CurrentName):" -WindowTitle "Change Computer Name"
}

# Abort if user cancelled the input window or entered whitespace
if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Warning "[!] Operation cancelled by user or input was empty."
    return
}

# Input Sanitization
$CleanName = $NewName.Trim()

# NetBIOS Length Check
if ($CleanName.Length -gt 15) {
    Write-Error "[-] Validation Error: Name exceeds maximum length of 15 characters."
    return
}

# NetBIOS Standard Syntax Validation (No leading/trailing hyphens)
if ($CleanName -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,13}[a-zA-Z0-9])?$') {
    Write-Error "[-] Validation Error: Invalid computer name '$CleanName'."
    Write-Warning "[!] Allowed: Alphanumeric characters and internal hyphens."
    return
}

# Duplicate Name Check
if ($CleanName.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "[!] Target name '$CleanName' is identical to the current computer name."
    return
}

# Execute Action
Write-Output "[>] Changing computer name: $CurrentName -> $CleanName"

try {
    Rename-Computer -NewName $CleanName -Force -ErrorAction Stop

    Write-Output "[+] Computer name successfully changed to '$CleanName'."
    Write-Warning "[!] System restart required to complete changes."

    if ($Restart) {
        Write-Warning "[!] Reboot flag active. Restarting computer in 5 seconds..."
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
    else {
        Write-Output "[>] To apply changes later, restart the computer manually."
    }
}
catch {
    Write-Error "[-] Execution Failed: $($_.Exception.Message)"
}
