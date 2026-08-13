# ================================================================
# Script Name:   MasterCleanScript.ps1
# Path:          Tools/MasterCleanScript.ps1
# Description:   System Clean & Diagnostic Script (GitHub Driver Store Engine)
# Compatibility: PowerShell 5.1+, Visual Studio Code Terminal, Windows 10/11
# ================================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Force TLS 1.2 for secure GitHub downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
# 1. HELPER & OUTPUT FUNCTIONS
# ------------------------------------------------------------

function Write-Status {
    <#
    .SYNOPSIS
        Outputs formatted terminal messages with structured ASCII indicators.
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Type = "INFO"
    )

    switch ($Type) {
        "INFO"    { Write-Host "[>] $Message" -ForegroundColor Cyan }
        "SUCCESS" { Write-Host "[+] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[-] $Message" -ForegroundColor Red }
    }
}

function Test-IsAdministrator {
    $Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Ensure script is running with administrative privileges
if (-not (Test-IsAdministrator)) {
    Write-Status -Message "Administrative privileges required to perform system cleanup." -Type "ERROR"
    Write-Status -Message "Please relaunch PowerShell or VS Code as Administrator." -Type "WARN"
    exit 1
}

# ------------------------------------------------------------
# 2. MAINTENANCE FUNCTIONS
# ------------------------------------------------------------

function Get-BatteryHealth {
    Write-Status -Message "Analyzing Battery Health..." -Type "INFO"
    $XmlPath = Join-Path -Path $env:TEMP -ChildPath "bat_report.xml"

    try {
        $BatCheck = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $BatCheck) {
            Write-Status -Message "No battery detected (Desktop or Virtual Machine System)." -Type "INFO"
            return
        }

        # Generate battery report XML silently
        powercfg /batteryreport /output $XmlPath /xml | Out-Null

        if (Test-Path -Path $XmlPath) {
            [xml]$XmlReport = Get-Content -Path $XmlPath -ErrorAction Stop
            $DesignCap = $XmlReport.BatteryReport.Batteries.Battery.DesignCapacity | Select-Object -First 1
            $FullCap   = $XmlReport.BatteryReport.Batteries.Battery.FullChargeCapacity | Select-Object -First 1

            if ($DesignCap -and $FullCap -and ([int64]$DesignCap -gt 0)) {
                $Health = [math]::Round((([int64]$FullCap / [int64]$DesignCap) * 100), 1)
                $StatusType = if ($Health -ge 80) { "SUCCESS" } elseif ($Health -ge 50) { "WARN" } else { "ERROR" }

                Write-Status -Message "Battery Model: $($BatCheck.Name)" -Type "INFO"
                Write-Status -Message "Battery Health: $Health% ($FullCap mWh / $DesignCap mWh)" -Type $StatusType
            }
        }
    }
    catch {
        Write-Status -Message "Battery Analysis Error: $($_.Exception.Message)" -Type "ERROR"
    }
    finally {
        if (Test-Path -Path $XmlPath) { Remove-Item -Path $XmlPath -Force -ErrorAction SilentlyContinue }
    }
}

function Disable-Hibernation {
    Write-Status -Message "Disabling Hibernation to reclaim disk space (hiberfil.sys)..." -Type "INFO"
    try {
        powercfg /hibernate off
        Write-Status -Message "Hibernation disabled successfully." -Type "SUCCESS"
    }
    catch {
        Write-Status -Message "Failed to disable hibernation: $($_.Exception.Message)" -Type "WARN"
    }
}

function Invoke-ManualDiskCleanup {
    Write-Status -Message "Purging System Diagnostics, WER, and Browser Caches..." -Type "INFO"
    $Targets = @(
        "C:\Windows\Panther\*",
        "C:\Windows\inf\*.log",
        "C:\Windows\Logs\*",
        "C:\ProgramData\Microsoft\Windows\WER\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
        "C:\`$Recycle.Bin\*"
    )

    foreach ($Path in $Targets) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Status -Message "Manual disk cache purge completed." -Type "SUCCESS"
}

function Invoke-ExcessCleanup {
    Write-Status -Message "Stopping update services prior to cache purge..." -Type "INFO"
    $Services = @("bits", "dosvc", "wuauserv")

    foreach ($Svc in $Services) {
        Stop-Service -Name $Svc -Force -ErrorAction SilentlyContinue
    }

    try {
        Write-Status -Message "Purging temporary folders and SoftwareDistribution cache..." -Type "INFO"
        $Folders = @($env:TEMP, "C:\Windows\Temp", "C:\Windows\Prefetch", "C:\Windows\SoftwareDistribution\Download")

        foreach ($Folder in $Folders) {
            if (Test-Path -Path $Folder) {
                Get-ChildItem -Path "$Folder\*" -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Status -Message "Temporary directories and service caches purged successfully." -Type "SUCCESS"
    }
    finally {
        Write-Status -Message "Restarting update services..." -Type "INFO"
        foreach ($Svc in $Services) {
            Start-Service -Name $Svc -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-DriverStoreCleanup {
    <#
    .SYNOPSIS
        Downloads DriverStoreExplorer from GitHub, executes driver store purging,
        and scans for orphaned installer files. Positioned at the end of execution.
    #>
    Write-Status -Message "Starting Driver Store and Orphaned File Maintenance..." -Type "INFO"

    # Orphaned MSI/MSP Registry Check
    Write-Status -Message "Scanning for orphaned MSI/MSP installer files..." -Type "INFO"
    $InstallerPath = "C:\Windows\Installer"

    if (Test-Path -Path $InstallerPath) {
        $AllFiles = Get-ChildItem -Path $InstallerPath -Include "*.msi", "*.msp" -Recurse -ErrorAction SilentlyContinue
        foreach ($File in $AllFiles) {
            $EscapedPath = $File.FullName -replace '\\', '\\'
            $Match = Get-CimInstance -Query "SELECT LocalPackage FROM Win32_Product WHERE LocalPackage = '$EscapedPath'" -ErrorAction SilentlyContinue

            if (-not $Match) {
                try {
                    Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                    Write-Status -Message "Deleted orphaned installer: $($File.Name)" -Type "SUCCESS"
                }
                catch {
                    Write-Status -Message "Failed to delete $($File.Name): $($_.Exception.Message)" -Type "WARN"
                }
            }
        }
    }

    # Driver Store Explorer GitHub Asset Configuration
    $DownloadUrl = "https://github.com/lostindark/DriverStoreExplorer/releases/download/v0.12.64/DriverStoreExplorer.v0.12.64.zip"
    $ExtractPath = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer"
    $ZipPath     = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer.zip"

    try {
        if (-not (Test-Path -Path $ExtractPath)) {
            New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        }

        Write-Status -Message "Downloading DriverStoreExplorer package from GitHub..." -Type "INFO"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

        Write-Status -Message "Extracting DriverStoreExplorer binary archive..." -Type "INFO"
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop

        # Locate Rapr.exe within extracted path
        $ExeFile = Get-ChildItem -Path $ExtractPath -Recurse -Filter "Rapr.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -ne $ExeFile) {
            Write-Status -Message "Launching DriverStoreExplorer background process (/purge)..." -Type "INFO"
            $DriverProcess = Start-Process -FilePath $ExeFile.FullName -ArgumentList "/purge" -Verb RunAs -PassThru

            if ($null -ne $DriverProcess) {
                Write-Status -Message "Waiting for DriverStoreExplorer completion..." -Type "INFO"

                # Wait up to 5 minutes (300,000 ms) to avoid process deadlocks
                $HasExited = $DriverProcess.WaitForExit(300000)

                if ($HasExited) {
                    Write-Status -Message "Driver Store cleanup completed successfully." -Type "SUCCESS"
                }
                else {
                    Write-Status -Message "Driver Store cleanup timed out. Terminating background process." -Type "WARN"
                    Stop-Process -Id $DriverProcess.Id -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Status -Message "Rapr.exe binary not found in extracted archive." -Type "ERROR"
        }
    }
    catch {
        Write-Status -Message "Driver Store Maintenance Error: $($_.Exception.Message)" -Type "ERROR"
    }
    finally {
        # Cleanup temporary archive files
        if (Test-Path -Path $ZipPath)     { Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ------------------------------------------------------------
# 3. MAIN SCRIPT EXECUTION
# ------------------------------------------------------------
Clear-Host

$CompSys = Get-CimInstance Win32_ComputerSystem
$Bios    = Get-CimInstance Win32_Bios
$OS      = Get-CimInstance Win32_OperatingSystem

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Master Maintenance Script Execution"       -ForegroundColor White
Write-Host " Model:    $($CompSys.Model)"              -ForegroundColor Gray
Write-Host " S/N:      $($Bios.SerialNumber)"          -ForegroundColor Gray
Write-Host " OS:       $($OS.Caption) Build $($OS.BuildNumber)" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Battery Diagnostic Check
Get-BatteryHealth
pause
# 2. Hibernation Removal
Disable-Hibernation
pause
# 3. Disk & Browser Cache Purge
Invoke-ManualDiskCleanup
pause
# 4. Service Cache & Temp Files Cleanup
Invoke-ExcessCleanup
pause
# 5. Driver Store Explorer Download & Driver Cleanup (At End)
Invoke-DriverStoreCleanup
pause
Write-Host ""
Write-Status -Message "Master maintenance operations completed successfully." -Type "SUCCESS"
