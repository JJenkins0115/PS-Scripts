#requires -RunAsAdministrator

<#
.SYNOPSIS
    Sequentially repairs a broken Active Directory computer secure channel.

.DESCRIPTION
    Repair order:
      1. Test-ComputerSecureChannel -Repair
      2. Reset-ComputerMachinePassword
      3. NLTEST /sc_reset
      4. Optional domain removal/rejoin

    The script stops immediately once the secure channel is verified healthy.

.NOTES
    Run as Administrator.
#>

$ErrorActionPreference = 'Stop'

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Active Directory Secure Channel Repair" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Helper: Check secure channel
# ------------------------------------------------------------

function Test-SecureChannel {
    Write-Host "Checking secure channel..." -ForegroundColor Cyan

    try {
        $Result = Test-ComputerSecureChannel -ErrorAction Stop

        if ($Result) {
            Write-Host "Secure channel is HEALTHY." -ForegroundColor Green
            return $true
        }

        Write-Host "Secure channel is BROKEN." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Warning "Unable to test secure channel: $($_.Exception.Message)"
        return $false
    }
}

# ------------------------------------------------------------
# Helper: Verify after repair
# ------------------------------------------------------------

function Confirm-Repair {
    param(
        [string]$Method
    )

    Write-Host ""
    Write-Host "Verifying repair from: $Method" -ForegroundColor Cyan

    # Give AD replication / Netlogon a moment
    Start-Sleep -Seconds 3

    try {
        $Healthy = Test-ComputerSecureChannel -ErrorAction Stop

        if ($Healthy) {
            Write-Host ""
            Write-Host "==============================================" -ForegroundColor Green
            Write-Host " SUCCESS" -ForegroundColor Green
            Write-Host " Secure channel repaired using: $Method" -ForegroundColor Green
            Write-Host "==============================================" -ForegroundColor Green
            return $true
        }

        Write-Host "Secure channel is still broken." -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Warning "Verification failed: $($_.Exception.Message)"
        return $false
    }
}

# ------------------------------------------------------------
# Initial check
# ------------------------------------------------------------

if (Test-SecureChannel) {
    Write-Host ""
    Write-Host "No repair is necessary." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Secure channel repair is required." -ForegroundColor Yellow
Write-Host ""

# ------------------------------------------------------------
# Get credentials once
# ------------------------------------------------------------

$Cred = Get-Credential `
    -Message "Enter credentials with permission to reset the computer account"

if (-not $Cred) {
    Write-Error "No credentials supplied. Exiting."
    exit 1
}

# ------------------------------------------------------------
# Get domain information
# ------------------------------------------------------------

$Domain = $env:USERDNSDOMAIN

if ([string]::IsNullOrWhiteSpace($Domain)) {
    try {
        $Domain = (Get-CimInstance Win32_ComputerSystem).Domain
    }
    catch {
        Write-Warning "Unable to automatically determine the domain."
    }
}

Write-Host "Detected domain: $Domain" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# METHOD 1
# ============================================================

Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 1: Test-ComputerSecureChannel -Repair" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {
    Test-ComputerSecureChannel `
        -Repair `
        -Credential $Cred `
        -ErrorAction Stop | Out-Host

    if (Confirm-Repair "Test-ComputerSecureChannel -Repair") {
        exit 0
    }
}
catch {
    Write-Warning "Method 1 failed: $($_.Exception.Message)"
}

# ============================================================
# METHOD 2
# ============================================================

Write-Host ""
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 2: Reset-ComputerMachinePassword" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {
    Reset-ComputerMachinePassword `
        -Credential $Cred `
        -ErrorAction Stop | Out-Host

    if (Confirm-Repair "Reset-ComputerMachinePassword") {
        exit 0
    }
}
catch {
    Write-Warning "Method 2 failed: $($_.Exception.Message)"
}

# ============================================================
# METHOD 3
# ============================================================

Write-Host ""
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 3: NLTEST /sc_reset" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {

    if ([string]::IsNullOrWhiteSpace($Domain)) {
        throw "Domain name could not be determined."
    }

    Write-Host "Running: nltest /sc_reset:$Domain" -ForegroundColor Gray

    & nltest.exe "/sc_reset:$Domain"

    if ($LASTEXITCODE -eq 0) {

        Write-Host "NLTEST completed successfully." -ForegroundColor Green

        if (Confirm-Repair "NLTEST /sc_reset") {
            exit 0
        }
    }
    else {
        Write-Warning "NLTEST failed with exit code $LASTEXITCODE."
    }
}
catch {
    Write-Warning "Method 3 failed: $($_.Exception.Message)"
}

# ============================================================
# ALL AUTOMATIC METHODS FAILED
# ============================================================

Write-Host ""
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "Automatic secure-channel repair failed." -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""

$Choice = Read-Host "Attempt a domain remove/rejoin? (Y/N)"

if ($Choice -notmatch '^[Yy]$') {
    Write-Host ""
    Write-Host "No domain changes were made." -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------
# Confirm domain
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Domain)) {
    $Domain = Read-Host "Enter the AD domain name"
}

Write-Host ""
Write-Host "WARNING: This will remove the computer from the domain" -ForegroundColor Red
Write-Host "and then attempt to join it again." -ForegroundColor Red
Write-Host ""

$Confirm = Read-Host "Type REJOIN to continue"

if ($Confirm -ne 'REJOIN') {
    Write-Host "Domain rejoin cancelled." -ForegroundColor Yellow
    exit 1
}

# ============================================================
# REMOVE FROM DOMAIN
# ============================================================

Write-Host ""
Write-Host "Removing computer from domain..." -ForegroundColor Cyan

try {

    Remove-Computer `
        -UnjoinDomainCredential $Cred `
        -Force `
        -ErrorAction Stop

    Write-Host "Computer removed from domain." -ForegroundColor Green

}
catch {
    Write-Error "Domain removal failed: $($_.Exception.Message)"
    exit 1
}

# ============================================================
# REJOIN DOMAIN
# ============================================================

Write-Host ""
Write-Host "Joining computer back to: $Domain" -ForegroundColor Cyan

try {

    Add-Computer `
        -DomainName $Domain `
        -Credential $Cred `
        -Force `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Computer successfully joined the domain." -ForegroundColor Green
    Write-Host "A restart is required." -ForegroundColor Yellow

    $Restart = Read-Host "Restart now? (Y/N)"

    if ($Restart -match '^[Yy]$') {
        Restart-Computer -Force
    }
    else {
        Write-Host ""
        Write-Host "Please restart the computer manually." -ForegroundColor Yellow
    }

}
catch {
    Write-Error "Domain rejoin failed: $($_.Exception.Message)"
    exit 1
}
