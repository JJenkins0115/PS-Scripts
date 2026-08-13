# ============================================================
# Main.ps1 - OPTIMIZED SCRIPT EXECUTION ENGINE
# ============================================================

function Start-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )

    Write-ConsoleOutput -Text "`r`n[>] Preparing script '$($Script.Name)'..." -Color $ColorInfoFg
    $LocalFile = Get-RemoteScript -Script $Script

    if (-not $LocalFile -or -not (Test-Path -Path $LocalFile)) {
        Write-ConsoleOutput -Text "[-] Error: Local script file could not be found." -Color $ColorErrorFg
        return
    }

    Write-ConsoleOutput -Text "[+] Executing: $LocalFile" -Color $ColorInfoFg
    Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText

    # Execute asynchronously inside a background process runner thread
    [System.Threading.Tasks.Task]::Run([Action]{
        try {
            $PSI = New-Object System.Diagnostics.ProcessStartInfo
            $PSI.FileName               = "powershell.exe"
            # -NoProfile -NonInteractive prevents loading user profile overhead and interactive console blocks
            $PSI.Arguments              = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$LocalFile`""
            $PSI.RedirectStandardOutput = $true
            $PSI.RedirectStandardError  = $true
            $PSI.UseShellExecute        = $false
            $PSI.CreateNoWindow         = $true

            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $PSI

            if (-not $Process.Start()) {
                Write-ConsoleOutput -Text "[-] Failed to launch PowerShell host process." -Color $ColorErrorFg
                return
            }

            # ============================================================
            # STREAM READER LOOP (Prevents Event Queue Thread Deadlocks)
            # ============================================================
            
            # Read stdout line-by-line as it emits from the process stream
            while (-not $Process.StandardOutput.EndOfStream) {
                $Line = $Process.StandardOutput.ReadLine()
                if ($null -ne $Line) {
                    Write-ConsoleOutput -Text $Line -Color $ColorConsoleFg
                }
            }

            # Capture remaining error stream
            $ErrorBuffer = $Process.StandardError.ReadToEnd()
            if (-not [string]::IsNullOrWhiteSpace($ErrorBuffer)) {
                Write-ConsoleOutput -Text "[ERROR] $ErrorBuffer" -Color $ColorErrorFg
            }

            $Process.WaitForExit()
            $ExitCode = $Process.ExitCode
            $Process.Dispose()

            Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText
            if ($ExitCode -eq 0) {
                Write-ConsoleOutput -Text "[+] Execution finished successfully (Exit Code: 0)." -Color $ColorInfoFg
            }
            else {
                Write-ConsoleOutput -Text "[-] Execution finished with errors (Exit Code: $ExitCode)." -Color $ColorErrorFg
            }
        }
        catch {
            Write-ConsoleOutput -Text "[-] Execution Exception: $($_.Exception.Message)" -Color $ColorErrorFg
        }
    }) | Out-Null
}
