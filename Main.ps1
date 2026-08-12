# ==============================
# PowerShell Tools - Main Menu
# ==============================

$GitHubUser = "JJenkins0115"
$Repository = "PS-Scripts"
$Branch = "main"

$RawBase = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch"
$ApiUrl = "https://api.github.com/repos/$GitHubUser/$Repository/contents"

while ($true) {

    Clear-Host

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "        PowerShell Tools Console" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Get scripts from GitHub
    try {
        $Files = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop

        $Scripts = @(
            $Files |
                Where-Object {
                    $_.type -eq "file" -and
                    $_.name -like "*.ps1" -and
                    $_.name -ne "Main.ps1"
                } |
                Sort-Object name
        )
    }
    catch {
        Write-Host "Unable to retrieve scripts from GitHub." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Read-Host "Press Enter to try again"
        continue
    }

    # Display scripts
    Write-Host "Available Scripts:" -ForegroundColor Green
    Write-Host ""

    for ($i = 0; $i -lt $Scripts.Count; $i++) {
        Write-Host " [$($i + 1)] $($Scripts[$i].name)"
    }

    Write-Host ""
    Write-Host " [R] Refresh"
    Write-Host " [Q] Quit"
    Write-Host ""

    $Choice = Read-Host "Select a script"

    # Quit
    if ($Choice -eq "Q" -or $Choice -eq "q") {
        Clear-Host
        exit
    }

    # Refresh
    if ($Choice -eq "R" -or $Choice -eq "r") {
        continue
    }

    # Validate selection
    $Number = 0

    if (-not [int]::TryParse($Choice, [ref]$Number)) {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep 2
        continue
    }

    if ($Number -lt 1 -or $Number -gt $Scripts.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep 2
        continue
    }

    # Selected script
    $SelectedScript = $Scripts[$Number - 1]

    Write-Host ""
    Write-Host "Selected: $($SelectedScript.name)" -ForegroundColor Cyan

    # Download selected script
    $ScriptUrl = "$RawBase/$($SelectedScript.name)"
    $TempFile = Join-Path $env:TEMP $SelectedScript.name

    try {

        Write-Host "Downloading..." -ForegroundColor Yellow

        Invoke-WebRequest `
            -Uri $ScriptUrl `
            -OutFile $TempFile `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "Launching Administrator PowerShell..." -ForegroundColor Green
        Write-Host ""

        # Launch selected script in a new elevated PowerShell window
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TempFile`""

    }
    catch {

        Write-Host ""
        Write-Host "Failed to launch script." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Start-Sleep 3
    }

    # Give the new PowerShell window time to start
    Start-Sleep -Seconds 2

    # Return to main menu
    continue
}

Write-Host "Running $($SelectedScript.name)..." -ForegroundColor Green
Write-Host ""

Invoke-Expression $ScriptContent
