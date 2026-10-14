#requires -RunAsAdministrator

<#
.SYNOPSIS
    Active Directory Domain Trust Diagnostic and Automated Repair Tool.

.DESCRIPTION
    1. Validates domain membership and DC reachability.
    2. Runs initial health check on secure channel.
    3. Prompts once for credentials and executes a 4-stage repair escalation:
       - Test-ComputerSecureChannel -Repair
       - Reset-ComputerMachinePassword
       - NLTEST /sc_reset
       - Domain Unjoin / Rejoin (Fallback)
    4. Triggers Windows LAPS password rotation upon successful repair.
#>

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 55) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host ("=" * 55) -ForegroundColor Cyan
    Write-Host ""
}

function Test-SecureChannelHealth {
    try {
        return (Test-ComputerSecureChannel -ErrorAction Stop)
    }
    catch {
        Write-Warning "Secure channel query failed: $($_.Exception.Message)"
        return $false
    }
}

function Confirm-RepairStep {
    param([string]$Method)
    
    Write-Host ""
    Write-Host "Verifying repair step: $Method..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3

    if (Test-SecureChannelHealth) {
        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host " SUCCESS: Secure channel repaired using $Method" -ForegroundColor Green
        Write-Host "==============================================" -ForegroundColor Green
        return $true
    }
    
    Write-Host "Secure channel remains unhealthy." -ForegroundColor Yellow
    return $false
}

function Invoke-LapsRotation {
    Write-Host ""
    Write-Host "Rotating Windows LAPS password..." -ForegroundColor Cyan
    try {
        Reset-LapsPassword -ErrorAction Stop
        Write-Host "LAPS password rotation successfully triggered." -ForegroundColor Green
    }
    catch {
        Write-Warning "LAPS rotation skipped or failed: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# 1. Domain Membership & Network Pre-flight
# ------------------------------------------------------------

Write-SectionHeader "DOMAIN TRUST DIAGNOSTIC & REPAIR TOOL"

$Computer =$env:COMPUTERNAME
$Domain =$env:USERDNSDOMAIN

if ([string]::IsNullOrWhiteSpace($Domain)) {
    try {
        $Domain = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).Domain
    }
    catch {
        $Domain =$null
    }
}

Write-Host "Computer Name : $Computer" -ForegroundColor White
Write-Host "Active Domain : $Domain" -ForegroundColor White

if ([string]::IsNullOrWhiteSpace($Domain) -or$Domain -eq $Computer -or$Domain -eq "WORKGROUP") {
    Write-Host ""
    Write-Error "ERROR: This machine is not joined to an Active Directory domain."
    exit 1
}

# Test Domain Controller reachability
Write-Host ""
Write-Host "Checking Domain Controller reachability..." -ForegroundColor Cyan
& nltest.exe "/dsgetdc:$Domain" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Could not locate a Domain Controller for $Domain." -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - DNS pointing to improper DNS server"
    Write-Host "  - Network interface offline or disconnected"
    Write-Host "  - Domain Controller unreachable / VPN required"
    Write-Host ""
    Write-Host "Current DNS IPv4 Configuration:" -ForegroundColor Cyan
    Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize
    exit 1
}

Write-Host "Domain Controller located successfully." -ForegroundColor Green

# ------------------------------------------------------------
# 2. Initial Health Check
# ------------------------------------------------------------

Write-Host ""
Write-Host "Checking secure channel status..." -ForegroundColor Cyan
if (Test-SecureChannelHealth) {
    Write-Host "Secure channel is HEALTHY. No repair necessary." -ForegroundColor Green
    
    $RotateLaps = Read-Host "`nWould you like to trigger a LAPS password reset anyway? (Y/N)"
    if ($RotateLaps -match '^[Yy]$') {
        Invoke-LapsRotation
    }
    exit 0
}

Write-Host "Secure channel is BROKEN." -ForegroundColor Yellow

# ------------------------------------------------------------
# 3. Obtain Credentials
# ------------------------------------------------------------

Write-Host ""
$Cred = Get-Credential -Message "Enter credentials with AD permissions to repair this computer account"

if (-not $Cred) {
    Write-Error "No credentials supplied. Aborting repair."
    exit 1
}

# ------------------------------------------------------------
# 4. Repair Escalation Sequence
# ------------------------------------------------------------

# --- METHOD 1: Test-ComputerSecureChannel -Repair ---
Write-Host ""
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 1: Test-ComputerSecureChannel -Repair" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {
    Test-ComputerSecureChannel -Repair -Credential $Cred -ErrorAction Stop | Out-Null
    if (Confirm-RepairStep "Test-ComputerSecureChannel -Repair") {
        Invoke-LapsRotation
        $Restart = Read-Host "`nRestart computer now? (Y/N)"
        if ($Restart -match '^[Yy]$') { Restart-Computer -Force }
        exit 0
    }
}
catch {
    Write-Warning "Method 1 failed: $($_.Exception.Message)"
}

# --- METHOD 2: Reset-ComputerMachinePassword ---
Write-Host ""
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 2: Reset-ComputerMachinePassword" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {
    Reset-ComputerMachinePassword -Credential $Cred -ErrorAction Stop | Out-Null
    if (Confirm-RepairStep "Reset-ComputerMachinePassword") {
        Invoke-LapsRotation
        $Restart = Read-Host "`nRestart computer now? (Y/N)"
        if ($Restart -match '^[Yy]$') { Restart-Computer -Force }
        exit 0
    }
}
catch {
    Write-Warning "Method 2 failed: $($_.Exception.Message)"
}

# --- METHOD 3: NLTEST /sc_reset ---
Write-Host ""
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
Write-Host "METHOD 3: NLTEST /sc_reset" -ForegroundColor Cyan
Write-Host "----------------------------------------------" -ForegroundColor DarkGray

try {
    & nltest.exe "/sc_reset:$Domain" | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Confirm-RepairStep "NLTEST /sc_reset")) {
        Invoke-LapsRotation
        $Restart = Read-Host "`nRestart computer now? (Y/N)"
        if ($Restart -match '^[Yy]$') { Restart-Computer -Force }
        exit 0
    }
}
catch {
    Write-Warning "Method 3 failed: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# 5. Method 4: Domain Removal & Rejoin (Fallback)
# ------------------------------------------------------------

Write-Host ""
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host " Automatic secure-channel repair methods failed." -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow

$Choice = Read-Host "`nAttempt domain removal and rejoin? (Y/N)"

if ($Choice -notmatch '^[Yy]$') {
    Write-Host "No changes were made." -ForegroundColor Yellow
    exit 1
}

$Confirm = Read-Host "Type REJOIN to unjoin and rejoin domain '$Domain'"

if ($Confirm -ne 'REJOIN') {
    Write-Host "Domain rejoin cancelled." -ForegroundColor Yellow
    exit 1
}

# Remove Domain
Write-Host ""
Write-Host "Removing computer from $Domain..." -ForegroundColor Cyan
try {
    Remove-Computer -UnjoinDomainCredential $Cred -Force -ErrorAction Stop
    Write-Host "Computer unjoined successfully." -ForegroundColor Green
}
catch {
    Write-Error "Domain removal failed: $($_.Exception.Message)"
    exit 1
}

# Rejoin Domain
Write-Host ""
Write-Host "Rejoining computer to $Domain..." -ForegroundColor Cyan
try {
    Add-Computer -DomainName $Domain -Credential $Cred -Force -ErrorAction Stop
    Write-Host "Computer successfully rejoined to $Domain." -ForegroundColor Green
    
    Invoke-LapsRotation

    $Restart = Read-Host "`nA restart is required to complete rejoin. Restart now? (Y/N)"
    if ($Restart -match '^[Yy]$') {
        Restart-Computer -Force
    }
    else {
        Write-Host "Please restart the computer manually." -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Domain rejoin failed: $($_.Exception.Message)"
    exit 1
}
