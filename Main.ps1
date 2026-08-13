# ============================================================
# Script:        ChangeName.ps1
# Description:   Interactive NetBIOS Computer Name Change Utility
# Compatibility: Native PowerShell Terminal, PowerShell 5.1+ / Core
# ============================================================

# Check for elevated Administrator privileges
$Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Privilege Check Failed: Administrator rights required." -ForegroundColor Yellow
    Write-Host "[>] Requesting elevated process context..." -ForegroundColor Yellow

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs

    exit
}

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "               Change Computer Name Utility                 " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$CurrentName = $env:COMPUTERNAME
Write-Host "[>] Current Computer Name: $CurrentName" -ForegroundColor Gray
Write-Host ""

$NewName = Read-Host "Enter the new computer name"
$NewName = $NewName.Trim()

# Input Validation
if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Host "[-] Validation Error: No computer name was entered." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if ($NewName.Length -gt 15) {
    Write-Host "[-] Validation Error: Computer names cannot exceed 15 characters." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# NetBIOS naming convention check (alphanumeric and internal hyphens only)
if ($NewName -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,13}[a-zA-Z0-9])?$') {
    Write-Host "[-] Validation Error: Invalid name format." -ForegroundColor Red
    Write-Host "[!] Use only letters, numbers, and hyphens (no leading or trailing hyphens)." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

if ($NewName.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[!] Target name is identical to the current computer name." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "[>] Changing computer name:" -ForegroundColor Yellow
Write-Host "    $CurrentName -> $NewName" -ForegroundColor Cyan
Write-Host ""

try {
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop

    Write-Host "[+] Computer name changed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[!] A restart is required for the new name to take effect." -ForegroundColor Yellow
    Write-Host ""

    $Restart = Read-Host "Restart the computer now? (Y/N)"

    if ($Restart -eq "Y" -or $Restart -eq "y") {
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Host "[>] Remember to restart the computer later." -ForegroundColor Yellow
    }
}
catch {
    Write-Host ""
    Write-Host "[-] Failed to change the computer name." -ForegroundColor Red
    Write-Host "[-] Exception: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
