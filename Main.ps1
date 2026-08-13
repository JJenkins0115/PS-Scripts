# ============================================
# Main Toolkit Launcher
# ============================================

# Ensure script runs with proper privileges or host configuration
$ErrorActionPreference = "Stop"

function Write-ConsoleOutput {
    param(
        [string]$Text,
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White
    )
    Write-Host $Text -ForegroundColor $Color
}

function Get-RemoteScript {
    param(
        [PSCustomObject]$Script
    )

    $TempDir = Join-Path -Path $env:TEMP -ChildPath "AdminToolkit"
    if (-not (Test-Path -Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }

    $LocalPath = Join-Path -Path $TempDir -ChildPath "$($Script.Name).ps1"

    # Simulated local script resolution/download logic
    if (Test-Path -Path $Script.Path) {
        Copy-Item -Path $Script.Path -Destination $LocalPath -Force
        return $LocalPath
    }
    
    return $null
}

function Start-Tool {
    param(
        [PSCustomObject]$Script
    )

    Write-ConsoleOutput -Text "`r`n[>] Downloading script '$($Script.Name)'..." -Color Cyan
    $LocalFile = Get-RemoteScript -Script $Script

    if (-not $LocalFile) { 
        Write-ConsoleOutput -Text "[-] Error: Script file could not be retrieved." -Color Red
        return 
    }

    Write-ConsoleOutput -Text "[+] Executing: $LocalFile" -Color Green
    Write-ConsoleOutput -Text "------------------------------------------------------------" -Color Gray

    try {
        & $LocalFile
    }
    catch {
        Write-ConsoleOutput -Text "[-] Execution Error: $($_.Exception.Message)" -Color Red
    }
}

# Define available toolkit scripts
$Tools = @(
    [PSCustomObject]@{
        Name = "ChangeName"
        Path = ".\Subfolder\ChangeName.ps1"
    }
)

# Main Execution Loop
Clear-Host
Write-ConsoleOutput -Text "========================================" -Color Cyan
Write-ConsoleOutput -Text "        IT Admin Toolkit Main           " -Color Cyan
Write-ConsoleOutput -Text "========================================" -Color Cyan
Write-ConsoleOutput -Text ""

for ($i = 0; $i -lt $Tools.Count; $i++) {
    Write-ConsoleOutput -Text " [$($i + 1)] $($Tools[$i].Name)" -Color Yellow
}

Write-ConsoleOutput -Text ""
$Selection = Read-Host "Select a script to run (1-$($Tools.Count))"

if ($Selection -match '^\d+$' -and [int]$Selection -ge 1 -and [int]$Selection -le $Tools.Count) {
    $SelectedScript = $Tools[[int]$Selection - 1]
    Start-Tool -Script $SelectedScript
}
else {
    Write-ConsoleOutput -Text "[-] Invalid selection." -Color Red
}

Read-Host "`nPress Enter to exit"
