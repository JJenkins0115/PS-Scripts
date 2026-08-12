# ==============================
# PowerShell Tools - Main Menu
# ==============================

$GitHubUser = "JJenkins0115"
$Repository = "PS-Scripts"
$Branch = "main"

$RawBase = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch"
$ApiUrl = "https://api.github.com/repos/$GitHubUser/$Repository/contents"

Clear-Host

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        PowerShell Tools Console" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    $Files = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing -ErrorAction Stop

    $Scripts = $Files |
        Where-Object {
            $_.type -eq "file" -and
            $_.name -like "*.ps1" -and
            $_.name -ne "Main.ps1"
        } |
        Sort-Object name
}
catch {
    Write-Host "Unable to retrieve scripts from GitHub." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

if ($Scripts.Count -eq 0) {
    Write-Host "No scripts were found." -ForegroundColor Yellow
    exit
}

Write-Host "Available Scripts:" -ForegroundColor Green
Write-Host ""

for ($i = 0; $i -lt $Scripts.Count; $i++) {
    Write-Host " [$($i + 1)] $($Scripts[$i].name)"
}

Write-Host ""
Write-Host " [Q] Quit"
Write-Host ""

$Choice = Read-Host "Select a script"

if ($Choice -eq "Q" -or $Choice -eq "q") {
    exit
}

$Number = 0

if (-not [int]::TryParse($Choice, [ref]$Number)) {
    Write-Host "Invalid selection." -ForegroundColor Red
    exit
}

if ($Number -lt 1 -or $Number -gt $Scripts.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    exit
}

$SelectedScript = $Scripts[$Number - 1]

Write-Host ""
Write-Host "Selected: $($SelectedScript.name)" -ForegroundColor Cyan
Write-Host "Downloading..." -ForegroundColor Yellow

$ScriptUrl = "$RawBase/$($SelectedScript.name)"

try {
    $ScriptContent = Invoke-RestMethod -Uri $ScriptUrl -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Host "Unable to download the script." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

Write-Host "Running $($SelectedScript.name)..." -ForegroundColor Green
Write-Host ""

Invoke-Expression $ScriptContent
