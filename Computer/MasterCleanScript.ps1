# ================================================================
# Script Name:   MasterCleanScript.ps1
# Path:          Tools/MasterCleanScript.ps1
# Description:   System Clean & Diagnostic Script (GitHub Driver Store Engine)
# ================================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$scriptStart = Get-Date 
$Global:ExecutionReport = [System.Collections.Generic.List[PSObject]]::new()
$Global:StopRequested = $false

# ------------------------------------------------------------
# CLEANUP & DIAGNOSTIC FUNCTIONS
# ------------------------------------------------------------

function Start-DSOrphanedFiles {
    Write-host "Starting Driver Store and System Maintenance Tasks..." "INFO"
    
    # Configure GitHub release asset parameters inside temporary workspace
    $downloadUrl = "https://github.com/lostindark/DriverStoreExplorer/releases/download/v0.12.64/DriverStoreExplorer.v0.12.64.zip"
    $extractPath = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer"
    $zipPath     = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer.zip"
    
    $driverProcess = $null

    try {
        if (-not (Test-Path $extractPath)) { 
            New-Item $extractPath -ItemType Directory -Force | Out-Null 
        }

        Write-host "Downloading DriverStoreExplorer from GitHub..." "INFO"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        
        Write-host "Extracting DriverStoreExplorer package..." "INFO"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        
        # Locate Rapr.exe regardless of folder depth inside the zip
        $exeFile = Get-ChildItem -Path $extractPath -Recurse -Filter "Rapr.exe" | Select-Object -First 1

        if ($exeFile) {
            Write-host "Launching DriverStoreExplorer background process (/purge)..." "INFO"
            $driverProcess = Start-Process -FilePath $exeFile.FullName -ArgumentList "/purge" -Verb RunAs -PassThru
        } else {
            Write-host "Rapr.exe not found inside extracted package." "ERROR"
        }

        # Orphaned MSI/MSP Registry Check
        Write-host "Scanning for orphaned MSI/MSP files..." "INFO"
        $InstallerPath = "C:\Windows\Installer"
        if (Test-Path $InstallerPath) {
            $AllFiles = Get-ChildItem -Path $InstallerPath -Include *.msi, *.msp -Recurse -ErrorAction SilentlyContinue
            foreach ($File in $AllFiles) {
                $Match = Get-CimInstance -Query "SELECT LocalPackage FROM Win32_Product WHERE LocalPackage = '$($File.FullName -replace '\\','\\')'" -ErrorAction SilentlyContinue
                if (-not $Match) {
                    try { 
                        Remove-Item $File.FullName -Force -ErrorAction Stop
                        Write-host "Deleted orphaned file: $($File.Name)" "SUCCESS"
                    } catch { }
                }
            }
        }

        if ($null -ne $driverProcess -and -not $driverProcess.HasExited) {
            Write-host "Waiting for DriverStoreExplorer task completion..." "INFO"
            $driverProcess | Wait-Process
            Write-host "Driver cleanup complete." "SUCCESS"
        }
    } 
    finally {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-BatteryHealth {
    Write-host "Analyzing Battery Health..." "INFO"
    $xmlPath = Join-Path -Path $env:TEMP -ChildPath "bat_report.xml"
    
    try {
        $batCheck = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $batCheck) {
            Write-host "No battery detected (Desktop System)." "INFO"
            return
        }

        powercfg /batteryreport /output $xmlPath /xml | Out-Null

        if (Test-Path $xmlPath) {
            [xml]$xmlReport = Get-Content $xmlPath
            $designCap = $xmlReport.BatteryReport.Batteries.Battery.DesignCapacity | Select-Object -First 1
            $fullCap   = $xmlReport.BatteryReport.Batteries.Battery.FullChargeCapacity | Select-Object -First 1

            if ($designCap -and $fullCap -and $designCap -gt 0) {
                $health = [math]::Round(($fullCap / $designCap) * 100, 1)
                $statusColor = if ($health -ge 80) { "SUCCESS" } elseif ($health -ge 50) { "WARN" } else { "ERROR" }

                Write-host "Battery Model: $($batCheck.Name)" "INFO"
                Write-host "Battery Health: $health% ($fullCap mWh / $designCap mWh)" $statusColor
            }
        }
    } 
    catch {
        Write-host "Battery Analysis Error: $($_.Exception.Message)" "ERROR"
    } 
    finally {
        if (Test-Path $xmlPath) { Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue }
    }
}

function AdditionalClean {
    Write-host "Disabling Hibernation to reclaim system storage..." "INFO"
    powercfg /hibernate off
}

function Start-ManualDiskCleanup {
    Write-host "Cleaning System Cache and Application remnants..." "INFO"
    $Targets = @(
        "C:\Windows\Panther\*", "C:\Windows\inf\*.log", "C:\Windows\Logs\*",
        "C:\ProgramData\Microsoft\Windows\WER\*", "$env:LOCALAPPDATA\Microsoft\Windows\WER\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*",
        "$env:LOCALAPPDATA\Local\Microsoft\Edge\User Data\Default\Cache\*",
        "C:\`$Recycle.Bin\*"
    )
    foreach ($Path in $Targets) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Start-ExcessCleanup {
    $Services = @("bits", "dosvc")
    $Services | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue }
    $Folders = @("$env:TEMP", "C:\Windows\Temp", "C:\Windows\Prefetch", "C:\Windows\SoftwareDistribution\Download")
    foreach ($f in $Folders) {
        if (Test-Path $f) { Get-ChildItem -Path "$f\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force }
    }
    Start-Service "wuauserv" -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------
# MAIN EXECUTION ENGINE
# ------------------------------------------------------------
Clear-Host
$computerName = $env:COMPUTERNAME
$compSys = Get-CimInstance Win32_ComputerSystem
$bios    = Get-CimInstance Win32_Bios
$os      = Get-CimInstance Win32_OperatingSystem

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Master Maintenance Script Execution" -ForegroundColor White
Write-Host " Model:    $($compSys.Model)" -ForegroundColor Gray
Write-Host " S/N:      $($bios.SerialNumber)" -ForegroundColor Gray
Write-Host " OS:       $($os.Caption) Build $($os.BuildNumber)" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan

Invoke-MaintenanceTask "Battery Health Report"                 { Get-BatteryHealth }
Invoke-MaintenanceTask "Hibernation & Storage Fix"             { AdditionalClean }
Invoke-MaintenanceTask "Orphaned Files & Driver Store"         { Start-DSOrphanedFiles }
Invoke-MaintenanceTask "Manual Disk Cache Purge"               { Start-ManualDiskCleanup }
Invoke-MaintenanceTask "Temp Files & Service Cache Purge"      { Start-ExcessCleanup }

Write-Host "`n==========================================" -ForegroundColor White
Write-Host "          FINAL TASK REPORT               " -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

foreach ($entry in $Global:ExecutionReport) {
    $color = if ($entry.Status -eq "COMPLETED") { "Green" } else { "Yellow" }
    Write-Host "$($entry.Task.PadRight(35)): " -NoNewline
    Write-Host $entry.Status -ForegroundColor $color
}

Write-DriveSpace -StepName "Final Operations"
