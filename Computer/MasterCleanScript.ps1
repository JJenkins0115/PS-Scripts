# ================================================================
# Script Name:   MasterCleanScript.ps1
# Description:   System Clean & Diagnostic Script (Remote Pipeline Optimized)
# Compatibility: PowerShell 5.1+, Visual Studio Code Terminal, GitHub iwr/iex
# ================================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Force TLS 1.2 to prevent download handshake failures in web execution streams
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
# 1. HELPER & OUTPUT FUNCTIONS
# ------------------------------------------------------------

function Write-Status {
    <#
    .SYNOPSIS
        Formats terminal output using standard ASCII indicators.
        Strictly avoids emojis to ensure cross-platform VS Code encoding safety.
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
    # Validates process elevation prior to running administrative system queries
    $Identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsValidZipArchive {
    <#
    .SYNOPSIS
        Inspects file magic bytes (0x50 0x4B 0x03 0x04) to verify standard ZIP format.
        Prevents downstream errors if GitHub returns an HTML error page.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) { return $false }

    $FileStream = $null
    try {
        $FileStream = [System.IO.File]::OpenRead($FilePath)
        if ($FileStream.Length -lt 4) { return $false }

        $Buffer = New-Object byte[] 4
        $BytesRead = $FileStream.Read($Buffer, 0, 4)

        if ($BytesRead -lt 4) { return $false }

        # Check for standard PK header
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
# 2. SYSTEM MAINTENANCE FUNCTIONS
# ------------------------------------------------------------

function Get-BatteryHealth {
    <#
    .SYNOPSIS
        Safe battery diagnostic check designed for desktop, laptop, and VM contexts under Strict Mode.
    #>
    Write-Status -Message "Analyzing Battery Health..." -Type "INFO"
    $XmlPath = Join-Path -Path $env:TEMP -ChildPath "bat_report.xml"

    try {
        $BatCheck = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $BatCheck) {
            Write-Status -Message "No battery hardware detected (Desktop or Virtual Machine System)." -Type "INFO"
            return
        }

        # Generate report XML quietly
        powercfg /batteryreport /output $XmlPath /xml | Out-Null

        if (Test-Path -Path $XmlPath) {
            [xml]$XmlReport = Get-Content -Path $XmlPath -ErrorAction Stop

            # Safe XML node traversal to prevent crashes on non-standard ACPI systems
            $BatteriesNode = $XmlReport.BatteryReport.Batteries
            if ($null -ne $BatteriesNode -and $null -ne $BatteriesNode.Battery) {
                $TargetBat = $BatteriesNode.Battery | Select-Object -First 1

                if ($null -ne $TargetBat -and $null -ne $TargetBat.DesignCapacity -and $null -ne $TargetBat.FullChargeCapacity) {
                    $DesignCap = [int64]$TargetBat.DesignCapacity
                    $FullCap   = [int64]$TargetBat.FullChargeCapacity

                    if ($DesignCap -gt 0) {
                        $Health = [math]::Round((($FullCap / $DesignCap) * 100), 1)
                        $StatusType = if ($Health -ge 80) { "SUCCESS" } elseif ($Health -ge 50) { "WARN" } else { "ERROR" }

                        Write-Status -Message "Battery Model: $($BatCheck.Name)" -Type "INFO"
                        Write-Status -Message "Battery Health: $Health% ($FullCap mWh / $DesignCap mWh)" -Type $StatusType
                    }
                }
            }
            else {
                Write-Status -Message "Battery report returned empty ACPI battery data structure." -Type "WARN"
            }
        }
    }
    catch {
        Write-Status -Message "Battery Analysis Warning: $($_.Exception.Message)" -Type "WARN"
    }
    finally {
        if (Test-Path -Path $XmlPath) { Remove-Item -Path $XmlPath -Force -ErrorAction SilentlyContinue }
    }
}

function Disable-Hibernation {
    Write-Status -Message "Disabling Hibernation to reclaim system storage..." -Type "INFO"
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
        Write-Status -Message "Restarting update services..." -Type "INFO"
        foreach ($Svc in $Services) {
            Start-Service -Name $Svc -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-DriverStoreCleanup {
    <#
    .SYNOPSIS
        Downloads DriverStoreExplorer from GitHub, explicitly unblocks NTFS Mark-of-the-Web
        streams, and executes background driver purging without extra UAC prompts.
    #>
    Write-Status -Message "Starting Driver Store and Orphaned File Maintenance..." -Type "INFO"

    # 1. Orphaned Installer Check
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

    # 2. Download and Execute DriverStoreExplorer
    $ExtractPath = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer"
    $ZipPath     = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer.zip"
    $DownloadUrl = $null

    try {
        Write-Status -Message "Querying GitHub API for latest DriverStoreExplorer release..." -Type "INFO"
        $ApiUrl   = "https://api.github.com/repos/lostindark/DriverStoreExplorer/releases/latest"
        $Release  = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = "PowerShell-Script" } -Method Get -ErrorAction Stop
        $ZipAsset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

        if ($null -ne $ZipAsset) {
            $DownloadUrl = $ZipAsset.browser_download_url
        }
    }
    catch {
        Write-Status -Message "GitHub API query failed. Falling back to release endpoint..." -Type "WARN"
    }

    if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
        $DownloadUrl = "https://github.com/lostindark/DriverStoreExplorer/releases/latest/download/DriverStoreExplorer.zip"
    }

    try {
        if (-not (Test-Path -Path $ExtractPath)) {
            New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        }

        Write-Status -Message "Downloading DriverStoreExplorer archive from GitHub..." -Type "INFO"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

        # Remove Internet Zone identifier from remote file stream
        Unblock-File -Path $ZipPath -ErrorAction SilentlyContinue

        if (-not (Test-IsValidZipArchive -FilePath $ZipPath)) {
            throw "Downloaded file is not a valid ZIP archive. Validate internet connectivity or firewall rules."
        }

        Write-Status -Message "Extracting binary package..." -Type "INFO"
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop

        # Remove Internet Zone identifier from extracted binaries to prevent SmartScreen execution block
        Get-ChildItem -Path $ExtractPath -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

        $ExeFile = Get-ChildItem -Path $ExtractPath -Recurse -Filter "Rapr.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -ne $ExeFile) {
            Write-Status -Message "Launching DriverStoreExplorer background process (/purge)..." -Type "INFO"

            # Executed directly without -Verb RunAs since process is already elevated at main block
            $DriverProcess = Start-Process -FilePath $ExeFile.FullName -ArgumentList "/purge" -PassThru

            if ($null -ne $DriverProcess) {
                Write-Status -Message "Waiting for DriverStoreExplorer task completion..." -Type "INFO"
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
            Write-Status -Message "Rapr.exe binary not found inside extracted archive." -Type "ERROR"
        }
    }
    catch {
        Write-Status -Message "Driver Store Maintenance Error: $($_.Exception.Message)" -Type "ERROR"
    }
    finally {
        if (Test-Path -Path $ZipPath)     { Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ------------------------------------------------------------
# 3. MAIN EXECUTION PIPELINE
# ------------------------------------------------------------

# Require administrator elevation for web execution streams
if (-not (Test-IsAdministrator)) {
    Write-Status -Message "Administrative privileges required to perform system maintenance tasks." -Type "ERROR"
    Write-Status -Message "Please launch VS Code or PowerShell as Administrator before executing this script." -Type "WARN"
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
