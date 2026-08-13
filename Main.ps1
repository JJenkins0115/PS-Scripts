# ============================================================
# Main Toolkit Launcher (VS Code Compatible)
# ============================================================

# Ensure clean global variable state to prevent menu auto-triggering on script re-runs
Remove-Variable Selection, SelectedScript, LocalFile, Tools -ErrorAction SilentlyContinue
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

    # Resolve local script file
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

    Write-ConsoleOutput -Text "`r`n[>] Preparing script '$($Script.Name)'..." -Color Cyan
    $LocalFile = Get-RemoteScript -Script $Script

    if (-not $LocalFile) { 
        Write-ConsoleOutput -Text "[-] Error: Script file could not be retrieved." -Color Red
        return 
    }

    Write-ConsoleOutput -Text "[+] Executing in dedicated process: $LocalFile" -Color Green
    Write-ConsoleOutput -Text "------------------------------------------------------------" -Color DarkGray

    try {
        # Using Start-Process isolates execution scopes completely.
        # This prevents child script variables and 'exit' commands from killing the Main.ps1 menu.
        $ProcessParams = @{
            FilePath     = "powershell.exe"
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$LocalFile`""
            Wait         = $true
            NoNewWindow  = $false # Set to $false to open in a distinct 1-to-1 window, or $true to run inline
        }
        Start-Process @ProcessParams
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

# Main Loop Strategy: Keeps menu active instead of terminating after one run
$KeepRunning = $true

while ($KeepRunning) {
    Clear-Host
    Write-ConsoleOutput -Text "========================================" -Color Cyan
    Write-ConsoleOutput -Text "        IT Admin Toolkit Main           " -Color Cyan
    Write-ConsoleOutput -Text "========================================" -Color Cyan
    Write-ConsoleOutput -Text ""

    for ($i = 0; $i -lt $Tools.Count; $i++) {
        Write-ConsoleOutput -Text " [$($i + 1)] $($Tools[$i].Name)" -Color Yellow
    }
    Write-ConsoleOutput -Text " [Q] Quit" -Color Red

    Write-ConsoleOutput -Text ""
    $Selection = Read-Host "Select a script to run"

    if ($Selection -eq 'Q' -or $Selection -eq 'q') {
        $KeepRunning = $false
        break
    }

    if ($Selection -match '^\d+$' -and [int]$Selection -ge 1 -and [int]$Selection -le $Tools.Count) {
        $SelectedScript = $Tools[[int]$Selection - 1]
        Start-Tool -Script $SelectedScript
        
        # Reset selection variable explicitly after execution
        $Selection = $null
        Write-ConsoleOutput -Text ""
        Read-Host "Press Enter to return to the main menu"
    }
    else {
        Write-ConsoleOutput -Text "[-] Invalid selection. Try again." -Color Red
        Start-Sleep -Seconds 1
    }
}
