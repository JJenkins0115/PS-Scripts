[CmdletBinding()]
param()

# ============================================================
# COMPLETE COMPUTER INFORMATION TOOL
# ============================================================
# Standalone Script
# Does NOT depend on AppCleanup.ps1
#
# Version: 2.0
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# BANNER
# ============================================================

function Show-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "             COMPLETE COMPUTER INFORMATION" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

}

# ============================================================
# COMPUTER / HARDWARE INFORMATION
# ============================================================

function Show-HardwareInformation {

    # --------------------------------------------------------
    # Gather Hardware Info
    # --------------------------------------------------------

    $CompSys = Get-CimInstance Win32_ComputerSystem
    $BIOS    = Get-CimInstance Win32_BIOS
    $OS      = Get-CimInstance Win32_OperatingSystem
    $CPU     = Get-CimInstance Win32_Processor |
               Select-Object -First 1

    # --------------------------------------------------------
    # Hardware Values
    # --------------------------------------------------------

    $Serial = $BIOS.SerialNumber
    $Model  = $CompSys.Model

    # --------------------------------------------------------
    # Windows Version / Build Info
    # --------------------------------------------------------

    $WinVersion = $OS.Caption
    $WinBuild   = $OS.BuildNumber

    $WinDisplayVersion = (
        Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    ).DisplayVersion

    # --------------------------------------------------------
    # Manufacturer
    # --------------------------------------------------------

    $Manufacturer = $CompSys.Manufacturer

    # --------------------------------------------------------
    # RAM
    # --------------------------------------------------------

    $TotalRAMGB = [math]::Round(
        $CompSys.TotalPhysicalMemory / 1GB,
        2
    )

    # --------------------------------------------------------
    # CPU
    # --------------------------------------------------------

    $CPUName = $CPU.Name
    $CPUCores = $CPU.NumberOfCores
    $CPUThreads = $CPU.NumberOfLogicalProcessors
    $CPUMaxSpeed = $CPU.MaxClockSpeed

    # --------------------------------------------------------
    # BIOS
    # --------------------------------------------------------

    $BIOSVersion = $BIOS.SMBIOSBIOSVersion
    $BIOSManufacturer = $BIOS.Manufacturer
    $BIOSDate = $BIOS.ReleaseDate

    if ($BIOSDate) {

        $BIOSDate = $BIOSDate.ToString("yyyy-MM-dd")
    }

    # --------------------------------------------------------
    # Windows Architecture
    # --------------------------------------------------------

    $Architecture = $OS.OSArchitecture

    # --------------------------------------------------------
    # Windows Install Date
    # --------------------------------------------------------

    $InstallDate = $OS.InstallDate

    if ($InstallDate) {

        $InstallDate = $InstallDate.ToString("yyyy-MM-dd HH:mm:ss")
    }

    # --------------------------------------------------------
    # Last Boot Time
    # --------------------------------------------------------

    $LastBoot = $OS.LastBootUpTime

    if ($LastBoot) {

        $LastBoot = $LastBoot.ToString("yyyy-MM-dd HH:mm:ss")
    }

    # ========================================================
    # DISPLAY
    # ========================================================

    Write-Host "HARDWARE INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Manufacturer        : {0}" -f $Manufacturer)
    Write-Host ("Model               : {0}" -f $Model)
    Write-Host ("Serial Number       : {0}" -f $Serial)

    Write-Host ""

    Write-Host "PROCESSOR" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("CPU                 : {0}" -f $CPUName)
    Write-Host ("Cores               : {0}" -f $CPUCores)
    Write-Host ("Logical Processors  : {0}" -f $CPUThreads)
    Write-Host ("Max Speed           : {0} MHz" -f $CPUMaxSpeed)

    Write-Host ""

    Write-Host "MEMORY" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Installed RAM       : {0} GB" -f $TotalRAMGB)

    Write-Host ""

    Write-Host "BIOS" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("BIOS Manufacturer    : {0}" -f $BIOSManufacturer)
    Write-Host ("BIOS Version         : {0}" -f $BIOSVersion)
    Write-Host ("BIOS Release Date    : {0}" -f $BIOSDate)

    Write-Host ""

    Write-Host "WINDOWS" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Windows Version      : {0}" -f $WinVersion)
    Write-Host ("Display Version      : {0}" -f $WinDisplayVersion)
    Write-Host ("Build Number         : {0}" -f $WinBuild)
    Write-Host ("Architecture         : {0}" -f $Architecture)

    Write-Host ""

    Write-Host "SYSTEM DATES" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Windows Installed    : {0}" -f $InstallDate)
    Write-Host ("Last Boot            : {0}" -f $LastBoot)

    Write-Host ""

}

# ============================================================
# DOMAIN INFORMATION
# ============================================================

function Show-DomainInformation {

    $Computer = Get-CimInstance Win32_ComputerSystem

    Write-Host "DOMAIN INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    if (!$Computer.PartOfDomain) {

        Write-Host "Domain Joined        : NO" -ForegroundColor Yellow
        Write-Host ("Workgroup            : {0}" -f $Computer.Workgroup)

        Write-Host ""

        return
    }

    Write-Host "Domain Joined        : YES" -ForegroundColor Green

    Write-Host ("Domain               : {0}" -f $Computer.Domain)

    Write-Host ("Domain Role          : {0}" -f $Computer.DomainRole)

    try {

        $Domain = `
            [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()

        Write-Host ("Domain Name          : {0}" -f $Domain.Name)

        Write-Host ("Forest               : {0}" -f $Domain.Forest.Name)

        Write-Host ""

        Write-Host "DOMAIN ROLES" -ForegroundColor Green
        Write-Host "----------------------------------------------------------"

        Write-Host ("PDC Emulator         : {0}" -f $Domain.PdcRoleOwner.Name)

        Write-Host ("RID Master           : {0}" -f $Domain.RidRoleOwner.Name)

        Write-Host ("Infrastructure       : {0}" -f $Domain.InfrastructureRoleOwner.Name)

    }
    catch {

        Write-Host ""
        Write-Host "Active Directory domain details unavailable." `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# USER INFORMATION
# ============================================================

function Show-UserInformation {

    $Identity = `
        [Security.Principal.WindowsIdentity]::GetCurrent()

    Write-Host "USER INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Current User         : {0}" -f $Identity.Name)

    Write-Host ("Username             : {0}" -f $env:USERNAME)

    Write-Host ("User Domain          : {0}" -f $env:USERDOMAIN)

    Write-Host ""

}

# ============================================================
# DOMAIN CONTROLLER
# ============================================================

function Show-DomainController {

    $Computer = Get-CimInstance Win32_ComputerSystem

    Write-Host "DOMAIN CONTROLLER" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    if (!$Computer.PartOfDomain) {

        Write-Host "Computer is not domain joined." `
            -ForegroundColor Yellow

        Write-Host ""

        return
    }

    # --------------------------------------------------------
    # NLTEST
    # --------------------------------------------------------

    try {

        $Result = nltest /dsgetdc:$($Computer.Domain) 2>&1

        if ($LASTEXITCODE -eq 0) {

            foreach ($Line in $Result) {

                Write-Host $Line
            }

            Write-Host ""

            return
        }

    }
    catch {
    }

    # --------------------------------------------------------
    # Active Directory Module
    # --------------------------------------------------------

    if (Get-Command `
        Get-ADDomainController `
        -ErrorAction SilentlyContinue) {

        try {

            $DC = Get-ADDomainController `
                -Discover `
                -ErrorAction Stop

            Write-Host ("Host Name            : {0}" -f $DC.HostName)

            Write-Host ("IPv4 Address         : {0}" -f $DC.IPv4Address)

            Write-Host ("Site                 : {0}" -f $DC.Site)

            Write-Host ("Operating System     : {0}" -f $DC.OperatingSystem)

            Write-Host ""

            return

        }
        catch {
        }
    }

    Write-Host "Unable to locate domain controller." `
        -ForegroundColor Yellow

    Write-Host ""

}

# ============================================================
# SECURE CHANNEL
# ============================================================

function Show-SecureChannel {

    $Computer = Get-CimInstance Win32_ComputerSystem

    Write-Host "DOMAIN SECURE CHANNEL" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    if (!$Computer.PartOfDomain) {

        Write-Host "Not applicable - computer is not domain joined."

        Write-Host ""

        return
    }

    try {

        $SecureChannel = Test-ComputerSecureChannel

        if ($SecureChannel) {

            Write-Host "Secure Channel      : HEALTHY" `
                -ForegroundColor Green

        }
        else {

            Write-Host "Secure Channel      : BROKEN" `
                -ForegroundColor Red
        }

    }
    catch {

        Write-Host "Secure Channel      : Unable to test" `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# DNS INFORMATION
# ============================================================

function Show-DNSInformation {

    Write-Host "DNS INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    try {

        $DNS = Get-DnsClientServerAddress `
            -AddressFamily IPv4 `
            -ErrorAction Stop

        foreach ($Adapter in $DNS) {

            if ($Adapter.ServerAddresses.Count -gt 0) {

                Write-Host ""

                Write-Host "Interface: $($Adapter.InterfaceAlias)"

                foreach ($Server in $Adapter.ServerAddresses) {

                    Write-Host "  DNS Server         : $Server"
                }
            }
        }
    }
    catch {

        Write-Host "Unable to retrieve DNS information." `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# NETWORK INFORMATION
# ============================================================

function Show-NetworkInformation {

    Write-Host "NETWORK INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    try {

        $Adapters = Get-NetAdapter `
            -Physical `
            -ErrorAction Stop

        foreach ($Adapter in $Adapters) {

            Write-Host ""

            Write-Host ("Adapter              : {0}" -f $Adapter.Name)

            Write-Host ("Description          : {0}" -f $Adapter.InterfaceDescription)

            Write-Host ("Status               : {0}" -f $Adapter.Status)

            Write-Host ("MAC Address          : {0}" -f $Adapter.MacAddress)

            $IPs = Get-NetIPAddress `
                -InterfaceIndex $Adapter.ifIndex `
                -AddressFamily IPv4 `
                -ErrorAction SilentlyContinue

            foreach ($IP in $IPs) {

                if (
                    $IP.IPAddress -notlike "127.*" -and
                    $IP.IPAddress -notlike "169.254.*"
                ) {

                    Write-Host ("IPv4 Address         : {0}" -f $IP.IPAddress)

                    Write-Host ("Prefix Length        : {0}" -f $IP.PrefixLength)
                }
            }
        }
    }
    catch {

        Write-Host "Unable to retrieve network information." `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# DISK INFORMATION
# ============================================================

function Show-DiskInformation {

    Write-Host "DISK INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    try {

        $Disks = Get-CimInstance Win32_LogicalDisk `
            -Filter "DriveType=3"

        foreach ($Disk in $Disks) {

            $SizeGB = [math]::Round(
                $Disk.Size / 1GB,
                2
            )

            $FreeGB = [math]::Round(
                $Disk.FreeSpace / 1GB,
                2
            )

            $UsedGB = $SizeGB - $FreeGB

            $FreePercent = if ($SizeGB -gt 0) {

                [math]::Round(
                    ($FreeGB / $SizeGB) * 100,
                    1
                )

            }
            else {

                0
            }

            Write-Host ""

            Write-Host ("Drive               : {0}" -f $Disk.DeviceID)

            Write-Host ("Volume              : {0}" -f $Disk.VolumeName)

            Write-Host ("Total Size          : {0} GB" -f $SizeGB)

            Write-Host ("Used                : {0} GB" -f $UsedGB)

            Write-Host ("Free                : {0} GB" -f $FreeGB)

            Write-Host ("Free Percentage     : {0}%" -f $FreePercent)

        }

    }
    catch {

        Write-Host "Unable to retrieve disk information." `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# DOMAIN CONNECTIVITY TEST
# ============================================================

function Test-DomainController {

    $Computer = Get-CimInstance Win32_ComputerSystem

    Write-Host "DOMAIN CONNECTIVITY TEST" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    if (!$Computer.PartOfDomain) {

        Write-Host "Computer is not domain joined."

        Write-Host ""

        return
    }

    try {

        $DCResult = nltest `
            /dsgetdc:$($Computer.Domain) `
            2>&1

        if ($LASTEXITCODE -eq 0) {

            $DCName = $null

            foreach ($Line in $DCResult) {

                if ($Line -match "\\\\([A-Za-z0-9\.\-_]+)") {

                    $DCName = $matches[1]

                    break
                }
            }

            if ($DCName) {

                Write-Host ("Domain Controller    : {0}" -f $DCName)

                Write-Host ""

                Write-Host "Testing connectivity..."

                if (
                    Test-Connection `
                        -ComputerName $DCName `
                        -Count 2 `
                        -Quiet
                ) {

                    Write-Host "Ping                 : SUCCESS" `
                        -ForegroundColor Green

                }
                else {

                    Write-Host "Ping                 : FAILED" `
                        -ForegroundColor Red
                }

            }
            else {

                Write-Host "Unable to determine domain controller." `
                    -ForegroundColor Yellow
            }

        }
        else {

            Write-Host "Unable to locate domain controller." `
                -ForegroundColor Red
        }

    }
    catch {

        Write-Host "Domain controller test failed." `
            -ForegroundColor Red
    }

    Write-Host ""

}

# ============================================================
# GROUP POLICY
# ============================================================

function Show-GroupPolicy {

    Write-Host "GROUP POLICY INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    try {

        gpresult /r /scope computer

    }
    catch {

        Write-Host "Unable to retrieve Group Policy information." `
            -ForegroundColor Yellow
    }

    Write-Host ""

}

# ============================================================
# FULL COMPUTER REPORT
# ============================================================

function Show-FullReport {

    Show-Banner

    Show-HardwareInformation

    Show-DomainInformation

    Show-UserInformation

    Show-DomainController

    Show-SecureChannel

    Show-DNSInformation

    Show-NetworkInformation

    Show-DiskInformation

    Test-DomainController

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Pause
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {

    while ($true) {

        Clear-Host

        $Computer = Get-CimInstance Win32_ComputerSystem

        Write-Host ""
        Write-Host "==========================================================" `
            -ForegroundColor Cyan

        Write-Host "          COMPLETE COMPUTER INFORMATION" `
            -ForegroundColor Cyan

        Write-Host "==========================================================" `
            -ForegroundColor Cyan

        Write-Host ""

        Write-Host ("Computer : {0}" -f $Computer.Name)

        if ($Computer.PartOfDomain) {

            Write-Host ("Domain   : {0}" -f $Computer.Domain)

        }
        else {

            Write-Host ("Workgroup: {0}" -f $Computer.Workgroup)
        }

        Write-Host ("User     : {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)

        Write-Host ""

        Write-Host "1  Complete Computer Report"
        Write-Host "2  Hardware Information"
        Write-Host "3  Windows Information"
        Write-Host "4  Domain Information"
        Write-Host "5  User Information"
        Write-Host "6  Domain Controller"
        Write-Host "7  Test Secure Channel"
        Write-Host "8  DNS Information"
        Write-Host "9  Network Information"
        Write-Host "10 Disk Information"
        Write-Host "11 Test Domain Connectivity"
        Write-Host "12 Group Policy Information"
        Write-Host "13 Exit"

        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice) {

            "1" {

                Show-FullReport
            }

            "2" {

                Clear-Host

                Show-Banner

                Show-HardwareInformation

                Pause
            }

            "3" {

                Clear-Host

                Show-Banner

                $OS = Get-CimInstance Win32_OperatingSystem

                $Registry = Get-ItemProperty `
                    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

                Write-Host "WINDOWS INFORMATION" -ForegroundColor Green
                Write-Host "----------------------------------------------------------"

                Write-Host ("Windows             : {0}" -f $OS.Caption)

                Write-Host ("Display Version     : {0}" -f $Registry.DisplayVersion)

                Write-Host ("Build               : {0}" -f $OS.BuildNumber)

                Write-Host ("Architecture        : {0}" -f $OS.OSArchitecture)

                Write-Host ("Install Date        : {0}" -f $OS.InstallDate)

                Write-Host ("Last Boot           : {0}" -f $OS.LastBootUpTime)

                Write-Host ""

                Pause
            }

            "4" {

                Clear-Host

                Show-Banner

                Show-DomainInformation

                Pause
            }

            "5" {

                Clear-Host

                Show-Banner

                Show-UserInformation

                Pause
            }

            "6" {

                Clear-Host

                Show-Banner

                Show-DomainController

                Pause
            }

            "7" {

                Clear-Host

                Show-Banner

                Show-SecureChannel

                Pause
            }

            "8" {

                Clear-Host

                Show-Banner

                Show-DNSInformation

                Pause
            }

            "9" {

                Clear-Host

                Show-Banner

                Show-NetworkInformation

                Pause
            }

            "10" {

                Clear-Host

                Show-Banner

                Show-DiskInformation

                Pause
            }

            "11" {

                Clear-Host

                Show-Banner

                Test-DomainController

                Pause
            }

            "12" {

                Clear-Host

                Show-Banner

                Show-GroupPolicy

                Pause
            }

            "13" {

                Clear-Host

                Write-Host ""
                Write-Host "Complete Computer Information Tool Closed." `
                    -ForegroundColor Cyan

                Write-Host ""

                return
            }

            default {

                Write-Host ""
                Write-Host "Invalid selection." `
                    -ForegroundColor Red

                Start-Sleep -Seconds 2
            }
        }
    }
}

# ============================================================
# START SCRIPT
# ============================================================

try {

    Show-MainMenu

}
catch {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Red

    Write-Host "Fatal Error" -ForegroundColor Red

    Write-Host "==========================================================" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host $_.Exception.Message `
        -ForegroundColor Yellow

    Write-Host ""

    Pause
}
