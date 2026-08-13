# ============================================================
# MAIN TOOL RUNNER - NATIVE INTERACTIVE CONSOLE LAUNCHER
# ============================================================

function Start-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )

    # Output status logging using clean ASCII indicators (VS Code optimized)
    Write-ConsoleOutput -Text "`r`n[>] Preparing script '$($Script.Name)'..." -Color $ColorInfoFg
    $LocalFile = Get-RemoteScript -Script $Script

    if (-not $LocalFile -or -not (Test-Path -Path $LocalFile)) {
        Write-ConsoleOutput -Text "[-] Error: Local script file could not be found at path." -Color $ColorErrorFg
        return
    }

    Write-ConsoleOutput -Text "[+] Spawning native PowerShell interactive session..." -Color $ColorInfoFg
    Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText

    try {
        # Construct process startup configuration for a dedicated interactive terminal window
        $ProcessParams = @{
            FilePath     = "powershell.exe"
            # -NoExit keeps the window open after script execution so administrators can view output/errors
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$LocalFile`""
            Verb         = "RunAs" # Triggers UAC elevation prompt if parent process is non-elevated
            WindowStyle  = "Normal"
        }

        # Spawn interactive terminal window directly
        $Process = Start-Process @ProcessParams -PassThru

        Write-ConsoleOutput -Text "[+] Process launched successfully." -Color $ColorInfoFg
        Write-ConsoleOutput -Text "[>] Process ID (PID): $($Process.Id)" -Color $ColorConsoleFg
        Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText
    }
    catch {
        # Catch UAC cancellation or execution policy blocks cleanly
        Write-ConsoleOutput -Text "[-] Failed to launch process: $($_.Exception.Message)" -Color $ColorErrorFg
    }
}
