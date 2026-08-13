# ================================================================
# Script Name:   MasterCleanScript.ps1
# Description:   System Clean & Diagnostic Script (Dynamic Driver Store Engine)
# Compatibility: PowerShell 5.1+, Visual Studio Code Terminal Host, Windows 10/11
# ================================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Force TLS 1.2 for secure GitHub REST API and download calls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
# 1. HELPER & TERMINAL OUTPUT FUNCTIONS
# ------------------------------------------------------------

function Write-Status {
    <#
    .SYNOPSIS
        Formats console output using structured ASCII indicator tags.
        Avoids unicode emojis for max host compatibility (VS Code / Standard Host).
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
    # Validates process elevation state before attempting system storage modifications
    $Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsValidZipArchive {
    <#
    .SYNOPSIS
        Inspects the first 4 bytes of a file to verify standard ZIP magic bytes (0x50 0x4B 0x03 0x04).
        Prevents Expand-Archive from attempting to extract HTML 404 pages or corrupted text streams.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) { return $false }

    $FileStream = $null
    try {
        # Open file in read mode to read file header
        $FileStream = [System.IO.File]::OpenRead($FilePath)
        if ($FileStream.Length -lt 4) { return $false }

        $Buffer = New-Object byte[] 4
        $BytesRead = $FileStream.Read($Buffer, 0, 4)

        if ($BytesRead -lt 4) { return $false }

        # PK.. header signature check (50 4B 03 04)
        return ($Buffer[0] -eq 0x50 -and $Buffer[1] -eq 0x4B -and $Buffer[2] -eq 0x03 -and $Buffer[3] -eq 0x04)
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $FileStream) {
            $FileStream.Close()
            $FileStream.Dispose()
        }
    }
}

# ------------------------------------------------------------
# 2. SYSTEM MAINTENANCE & CLEANUP FUNCTIONS
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

        # Generate powercfg XML report silently
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
    Write-Status -Message "Disabling Hibernation to reclaim system storage (hiberfil.sys)..." -Type "INFO"
    try {
        powercfg /hibernate off
        Write-Status -Message "Hibernation disabled successfully." -Type "SUCCESS"
    }
    catch {
        Write-Status -Message "Failed to disable hibernation: $($_.Exception.Message)" -Type "WARN"
    }
}

function Invoke-ManualDiskCleanup {
    Write-Status -Message "Cleaning System Diagnostics, WER, and Browser Caches..." -Type "INFO"
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
        # Guaranteed service recovery regardless of cleanup errors
        Write-Status -Message "Restarting update services..." -Type "INFO"
        foreach ($Svc in $Services) {
            Start-Service -Name $Svc -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-DriverStoreCleanup {
    <#
    .SYNOPSIS
        Dynamically downloads DriverStoreExplorer from GitHub REST API, verifies the
        binary payload stream to avoid unzipping HTML error pages, and executes purge.
    #>
    Write-Status -Message "Starting Driver Store and Orphaned File Maintenance..." -Type "INFO"

    # 1. Orphaned Installer Scan
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

    # 2. Dynamic DriverStoreExplorer Download & Verification Setup
    $ExtractPath = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer"
    $ZipPath     = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer.zip"
    $DownloadUrl = $null

    # Retrieve latest asset URL dynamically via GitHub API to avoid dead 404 links
    try {
        Write-Status -Message "Querying GitHub API for latest DriverStoreExplorer release..." -Type "INFO"
        $ApiUrl   = "https://api.github.com/repos/lostindark/DriverStoreExplorer/releases/latest"
        $Release  = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = "PowerShell-Script" } -Method Get -ErrorAction Stop
        $ZipAsset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

        if ($null -ne $ZipAsset) {
            $DownloadUrl = $ZipAsset.browser_download_url
            Write-Status -Message "Resolved release URL: $DownloadUrl" -Type "INFO"
        }
    }
    catch {
        Write-Status -Message "GitHub API query failed ($($_.Exception.Message)). Attempting direct download endpoint..." -Type "WARN"
    }

    # Fallback to general release redirection if API call was unsuccessful
    if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
        $DownloadUrl = "https://github.com/lostindark/DriverStoreExplorer/releases/latest/download/DriverStoreExplorer.zip"
    }

    try {
        if (-not (Test-Path -Path $ExtractPath)) {
            New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        }

        # Download remote package asset
        Write-Status -Message "Downloading DriverStoreExplorer package..." -Type "INFO"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

        # Validate file integrity prior to calling Expand-Archive
        if (-not (Test-IsValidZipArchive -FilePath $ZipPath)) {
            throw "Downloaded asset is not a valid ZIP archive (received an HTML page or invalid payload). Check network or proxy settings."
        }

        Write-Status -Message "Extracting binary archive..." -Type "INFO"
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop

        # Locate execution binary within target workspace
        $ExeFile = Get-ChildItem -Path $ExtractPath -Recurse -Filter "Rapr.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -ne $ExeFile) {
            Write-Status -Message "Launching DriverStoreExplorer background process (/purge)..." -Type "INFO"
            $DriverProcess = Start-Process -FilePath $ExeFile.FullName -ArgumentList "/purge" -Verb RunAs -PassThru

            if ($null -ne $DriverProcess) {
                Write-Status -Message "Waiting for DriverStoreExplorer task completion..." -Type "INFO"

                # Wait up to 5 minutes (300,000 ms) to avoid thread deadlock
                $HasExited = $DriverProcess.WaitForExit(300000)

                if ($HasExited) {
                    Write-Status -Message "Driver Store cleanup completed successfully." -Type "SUCCESS"
                }
                else {
                    Write-Status -Message "Driver Store cleanup timed out. Terminating process handle." -Type "WARN"
                    Stop-Process -Id $DriverProcess.Id -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Status -Message "Rapr.exe binary was not found inside extracted package." -Type "ERROR"
        }
    }
    catch {
        Write-Status -Message "Driver Store Maintenance Error: $($_.Exception.Message)" -Type "ERROR"
    }
    finally {
        # Purge workspace directories
        if (Test-Path -Path $ZipPath)     { Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ------------------------------------------------------------
# 3. APPLICATION ENTRY POINT
# ------------------------------------------------------------

if (-not (Test-IsAdministrator)) {
    Write-Status -Message "Administrative privileges required to run this script." -Type "ERROR"
    Write-Status -Message "Relaunch PowerShell or VS Code as Administrator." -Type "WARN"
    exit 1
}

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

# Pipeline Execution Order
Get-BatteryHealth
Disable-Hibernation
Invoke-ManualDiskCleanup
Invoke-ExcessCleanup
Invoke-DriverStoreCleanup

Write-Host ""
Write-Status -Message "Master maintenance tasks completed successfully." -Type "SUCCESS"
