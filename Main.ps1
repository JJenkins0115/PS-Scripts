# ============================================================
# MAIN TOOLKIT LAUNCHER (VS CODE & NATIVE TERMINAL OPTIMIZED)
# ============================================================

[CmdletBinding()]
param()

# Ensure strict execution standard
Set-StrictMode -Version 3.0

# Reset initial state to prevent sticky variable auto-execution
$Global:SelectedTool = $null

function Start-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ToolScript
    )

    Write-Host ""
    Write-Host "[>] Preparing script launch for '$($ToolScript.Name)'..." -ForegroundColor Cyan

    $LocalFile = Get-RemoteScript -Script $ToolScript

    if (-not $LocalFile -or -not (Test-Path -Path $LocalFile)) {
        Write-Host "[-] Error: Local script file could not be found." -ForegroundColor Red
        return
    }

    Write-Host "[+] Spawning independent 1-to-1 PowerShell window..." -ForegroundColor Green
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

    try {
        # Launching in an independent native console window.
        # Uses -NoExit so administrators can interact with output after completion.
        $StartInfo = @{
            FilePath     = "powershell.exe"
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$LocalFile`""
            Verb         = "RunAs"
            WindowStyle  = "Normal"
        }

        $Process = Start-Process @StartInfo -PassThru

        Write-Host "[+] Process spawned successfully. (PID: $($Process.Id))" -ForegroundColor Green
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "[-] Execution Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
# MAIN MENU LOOP
# ============================================================

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "                IT Admin Toolkit Launcher                   " -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Change Computer Name" -ForegroundColor Yellow
        Write-Host "  [2] Additional Tool Placeholder" -ForegroundColor Yellow
        Write-Host "  [Q] Quit" -ForegroundColor Red
        Write-Host ""

        $Selection = Read-Host "Select an option"

        switch ($Selection.Trim().ToUpper()) {
            "1" {
                $Tool = [PSCustomObject]@{
                    Name = "ChangeName"
                    Path = "Subfolder/ChangeName.ps1"
                }
                Start-Tool -ToolScript $Tool
                
                # Critical State Cleanup: Clear variable to prevent auto-loading loop
                $Tool = $null
                Read-Host "`nPress Enter to return to main menu"
            }
            "2" {
                Write-Host "[>] Placeholder selected." -ForegroundColor Gray
                Read-Host "`nPress Enter to return to main menu"
            }
            "Q" {
                Write-Host "[>] Exiting toolkit..." -ForegroundColor Gray
                return
            }
            Default {
                Write-Host "[!] Invalid selection, please try again." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

# Execute Menu
Show-MainMenu
