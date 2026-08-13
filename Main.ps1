# ============================================================
# MAIN TOOL RUNNER - ASYNCHRONOUS NON-BLOCKING ENGINE
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

    # Execute inside a background thread pool task
    [System.Threading.Tasks.Task]::Run([Action]{
        $Process = $null
        try {
            $PSI = New-Object System.Diagnostics.ProcessStartInfo
            $PSI.FileName               = "powershell.exe"
            # -NoProfile -NonInteractive ensures clean startup and prevents stdin blocking
            $PSI.Arguments              = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$LocalFile`""
            $PSI.RedirectStandardOutput = $true
            $PSI.RedirectStandardError  = $true
            $PSI.UseShellExecute        = $false
            $PSI.CreateNoWindow         = $true

            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $PSI

            # Scriptblock handlers for asynchronous data events
            $OutHandler = [System.Diagnostics.DataReceivedEventHandler]{
                param($sender, $eventArgs)
                if (-not [string]::IsNullOrEmpty($eventArgs.Data)) {
                    Write-ConsoleOutput -Text $eventArgs.Data -Color $ColorConsoleFg
                }
            }

            $ErrHandler = [System.Diagnostics.DataReceivedEventHandler]{
                param($sender, $eventArgs)
                if (-not [string]::IsNullOrEmpty($eventArgs.Data)) {
                    Write-ConsoleOutput -Text "[ERROR] $($eventArgs.Data)" -Color $ColorErrorFg
                }
            }

            # Attach .NET event handlers directly (bypasses PowerShell event subsystem)
            $Process.add_OutputDataReceived($OutHandler)
            $Process.add_ErrorDataReceived($ErrHandler)

            if (-not $Process.Start()) {
                Write-ConsoleOutput -Text "[-] Failed to start process: powershell.exe" -Color $ColorErrorFg
                return
            }

            # Begin asynchronous stream reading on background threads
            $Process.BeginOutputReadLine()
            $Process.BeginErrorReadLine()

            # Wait for process exit
            $Process.WaitForExit()
            $ExitCode = $Process.ExitCode

            Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText
            if ($ExitCode -eq 0) {
                Write-ConsoleOutput -Text "[+] Execution completed successfully." -Color $ColorInfoFg
            }
            else {
                Write-ConsoleOutput -Text "[-] Execution finished with exit code $ExitCode." -Color $ColorErrorFg
            }
        }
        catch {
            Write-ConsoleOutput -Text "[-] Process Execution Exception: $($_.Exception.Message)" -Color $ColorErrorFg
        }
        finally {
            if ($null -ne $Process) {
                $Process.Dispose()
            }
        }
    }) | Out-Null
}
