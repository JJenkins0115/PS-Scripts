# ============================================
# Change Computer Name
# ============================================

# Check for Administrator privileges
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Administrator privileges are required." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Yellow

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs

    exit
}

Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       Change Computer Name" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$CurrentName = $env:COMPUTERNAME

Write-Host "Current computer name: $CurrentName" -ForegroundColor Gray
Write-Host ""

$NewName = Read-Host "Enter the new computer name"

# Remove accidental spaces
$NewName = $NewName.Trim()

# Validate name
if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Host "No computer name was entered." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if ($NewName.Length -gt 15) {
    Write-Host "Computer names cannot exceed 15 characters." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if ($NewName -notmatch '^[a-zA-Z0-9-]+$') {
    Write-Host "Invalid computer name." -ForegroundColor Red
    Write-Host "Use only letters, numbers, and hyphens." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

if ($NewName -eq $CurrentName) {
    Write-Host "The new name is the same as the current name." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "Changing computer name:" -ForegroundColor Yellow
Write-Host "  $CurrentName -> $NewName" -ForegroundColor Cyan
Write-Host ""

try {

    Rename-Computer `
        -NewName $NewName `
        -Force `
        -ErrorAction Stop

    Write-Host "Computer name changed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "A restart is required for the new name to take effect." -ForegroundColor Yellow
    Write-Host ""

    $Restart = Read-Host "Restart the computer now? (Y/N)"

    if ($Restart -eq "Y" -or $Restart -eq "y") {
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Host "Remember to restart the computer later." -ForegroundColor Yellow
    }

}
catch {

    Write-Host ""
    Write-Host "Failed to change the computer name." -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"
