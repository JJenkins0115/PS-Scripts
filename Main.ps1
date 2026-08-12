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
        $Files = Invoke-RestMethod `
            -Uri $ApiUrl `
            -UseBasicParsing `
            -ErrorAction Stop

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
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        Read-Host "Press Enter to try again"
        continue
    }

    if ($Scripts.Count -eq 0) {
        Write-Host "No scripts were found." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }

    # Display menu
    Write-Host "Available Scripts:" -ForegroundColor Green
    Write-Host ""

    for ($i = 0; $i -lt $Scripts.Count; $i++) {
        Write-Host " [$($i + 1)] $($Scripts[$i].name)"
    }

    Write-Host ""
    Write-Host " [R] Refresh Scripts"
    Write-Host " [Q] Quit"
    Write-Host ""

    $Choice = Read-Host "Select a script"

    # Quit
    if ($Choice -eq "Q" -or $Choice -eq "q") {
        Clear-Host
        Write-Host "Goodbye!" -ForegroundColor Cyan
        exit
    }

    # Refresh
    if ($Choice -eq "R" -or $Choice -eq "r") {
        continue
    }

    # Validate number
    $Number = 0

    if (-not [int]::TryParse($Choice, [ref]$Number)) {
        Write-Host ""
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    if ($Number -lt 1 -or $Number -gt $Scripts.Count) {
        Write-Host ""
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    # Get selected script
    $SelectedScript = $Scripts[$Number - 1]

    Clear-Host

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Running: $($SelectedScript.name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $ScriptUrl = "$RawBase/$($SelectedScript.name)"
    $TempFile = Join-Path $env:TEMP $SelectedScript.name

    try {

        Write-Host "Downloading script..." -ForegroundColor Yellow

        Invoke-WebRequest `
            -Uri $ScriptUrl `
            -OutFile $TempFile `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "Starting script..." -ForegroundColor Green
        Write-Host ""

        # Run the selected script
        & $TempFile

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Script finished." -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "The script encountered an error." -ForegroundColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }
    finally {

        # Clean up downloaded script
        if (Test-Path $TempFile) {
            Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the main menu"

    # Loop back to menu
}

Write-Host "Running $($SelectedScript.name)..." -ForegroundColor Green
Write-Host ""

Invoke-Expression $ScriptContent
