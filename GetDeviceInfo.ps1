[CmdletBinding()]
param()

# ============================================================
# DOMAIN INFORMATION TOOL
# Standalone Script
# Version 1.0
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# BANNER
# ============================================================

function Show-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "                 DOMAIN INFORMATION" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

}

# ============================================================
# COMPUTER INFORMATION
# ============================================================

function Show-ComputerInformation {

    $Computer = Get-CimInstance Win32_ComputerSystem

    Write-Host "COMPUTER INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Computer Name       : {0}" -f $Computer.Name)
    Write-Host ("Manufacturer        : {0}" -f $Computer.Manufacturer)
    Write-Host ("Model               : {0}" -f $Computer.Model)

    if ($Computer.PartOfDomain) {

        Write-Host ("Domain              : {0}" -f $Computer.Domain)

    }
    else {

        Write-Host ("Workgroup           : {0}" -f $Computer.Workgroup)

    }

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

        Write-Host "Domain Joined       : NO" -ForegroundColor Yellow
        Write-Host ("Workgroup           : {0}" -f $Computer.Workgroup)

        Write-Host ""
        return
    }

    Write-Host "Domain Joined       : YES" -ForegroundColor Green
    Write-Host ("Domain              : {0}" -f $Computer.Domain)
    Write-Host ("Domain Role         : {0}" -f $Computer.DomainRole)

    try {

        $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()

        Write-Host ("Domain Name         : {0}" -f $Domain.Name)
        Write-Host ("Forest              : {0}" -f $Domain.Forest.Name)

        Write-Host ""

        Write-Host "DOMAIN ROLES" -ForegroundColor Green
        Write-Host "----------------------------------------------------------"

        Write-Host ("PDC Emulator        : {0}" -f $Domain.PdcRoleOwner.Name)
        Write-Host ("RID Master          : {0}" -f $Domain.RidRoleOwner.Name)
        Write-Host ("Infrastructure      : {0}" -f $Domain.InfrastructureRoleOwner.Name)

    }
    catch {

        Write-Host ""
        Write-Host "Active Directory domain details unavailable." `
            -ForegroundColor Yellow

    }

    Write-Host ""

}

# ============================================================
# CURRENT USER
# ============================================================

function Show-UserInformation {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    Write-Host "USER INFORMATION" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"

    Write-Host ("Current User        : {0}" -f $Identity.Name)
    Write-Host ("Username            : {0}" -f $env:USERNAME)
    Write-Host ("User Domain         : {0}" -f $env:USERDOMAIN)

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

        Write-Host "Computer is not domain joined." -ForegroundColor Yellow

        Write-Host ""

        return
    }

    # --------------------------------------------------------
    # Try nltest first
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
    # Try Active Directory module
    # --------------------------------------------------------

    if (Get-Command Get-ADDomainController -ErrorAction SilentlyContinue) {

        try {

            $DC = Get-ADDomainController `
                -Discover `
                -ErrorAction Stop

            Write-Host ("Host Name           : {0}" -f $DC.HostName)
            Write-Host ("IPv4 Address        : {0}" -f $DC.IPv4Address)
            Write-Host ("Site                : {0}" -f $DC.Site)
            Write-Host ("Operating System    : {0}" -f $DC.OperatingSystem)

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

            Write-Host "Secure Channel     : HEALTHY" `
                -ForegroundColor Green

        }
        else {

            Write-Host "Secure Channel     : BROKEN" `
                -ForegroundColor Red

        }

    }
    catch {

        Write-Host "Secure Channel     : Unable to test" `
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

                    Write-Host "  DNS Server       : $Server"

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

        $IPAddresses = Get-NetIPAddress `
            -AddressFamily IPv4 `
            -ErrorAction Stop |
            Where-Object {

                $_.IPAddress -notlike "127.*" -and
                $_.IPAddress -notlike "169.254.*"

            }

        foreach ($IP in $IPAddresses) {

            Write-Host ("Interface           : {0}" -f $IP.InterfaceAlias)
            Write-Host ("IPv4 Address        : {0}" -f $IP.IPAddress)
            Write-Host ("Prefix Length       : {0}" -f $IP.PrefixLength)
            Write-Host ""

        }

    }
    catch {

        Write-Host "Unable to retrieve network information." `
            -ForegroundColor Yellow

    }

}

# ============================================================
# PING DOMAIN CONTROLLER
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

        $DCResult = nltest /dsgetdc:$($Computer.Domain) 2>&1

        $DCName = $null

        foreach ($Line in $DCResult) {

            if ($Line -match "\\\\([A-Za-z0-9\.\-_]+)") {

                $DCName = $matches[1]

                break
            }
        }

        if ($DCName) {

            Write-Host "Domain Controller   : $DCName"

            Write-Host ""

            Write-Host "Testing connectivity..."

            if (Test-Connection `
                -ComputerName $DCName `
                -Count 2 `
                -Quiet) {

                Write-Host "Ping                : SUCCESS" `
                    -ForegroundColor Green

            }
            else {

                Write-Host "Ping                : FAILED" `
                    -ForegroundColor Red

            }

        }
        else {

            Write-Host "Could not determine domain controller." `
                -ForegroundColor Yellow

        }

    }
    catch {

        Write-Host "Domain controller test failed." `
            -ForegroundColor Red

    }

    Write-Host ""

}

# ============================================================
# GROUP POLICY INFORMATION
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
# FULL DOMAIN REPORT
# ============================================================

function Show-FullDomainReport {

    Show-Banner

    Show-ComputerInformation
    Show-DomainInformation
    Show-UserInformation
    Show-DomainController
    Show-SecureChannel
    Show-DNSInformation
    Show-NetworkInformation
    Test-DomainController

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

        Write-Host "                 DOMAIN INFORMATION" `
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

        Write-Host "1  Full Domain Report"
        Write-Host "2  Computer Information"
        Write-Host "3  Domain Information"
        Write-Host "4  User Information"
        Write-Host "5  Domain Controller"
        Write-Host "6  Test Secure Channel"
        Write-Host "7  DNS Information"
        Write-Host "8  Network Information"
        Write-Host "9  Test Domain Controller"
        Write-Host "10 Group Policy Information"
        Write-Host "11 Exit"

        Write-Host ""

        $Choice = Read-Host "Selection"

        switch ($Choice) {

            "1" {

                Show-FullDomainReport
            }

            "2" {

                Clear-Host
                Show-ComputerInformation
                Pause
            }

            "3" {

                Clear-Host
                Show-DomainInformation
                Pause
            }

            "4" {

                Clear-Host
                Show-UserInformation
                Pause
            }

            "5" {

                Clear-Host
                Show-DomainController
                Pause
            }

            "6" {

                Clear-Host
                Show-SecureChannel
                Pause
            }

            "7" {

                Clear-Host
                Show-DNSInformation
                Pause
            }

            "8" {

                Clear-Host
                Show-NetworkInformation
                Pause
            }

            "9" {

                Clear-Host
                Test-DomainController
                Pause
            }

            "10" {

                Clear-Host
                Show-GroupPolicy
                Pause
            }

            "11" {

                Clear-Host

                Write-Host ""
                Write-Host "Domain Information Tool Closed." `
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
# START
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

    Write-Host $_.Exception.Message -ForegroundColor Yellow

    Write-Host ""

    Pause
}
