# Repair-DomainTrust.ps1

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       DOMAIN TRUST REPAIR TOOL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$computer = $env:COMPUTERNAME
$domain = (Get-CimInstance Win32_ComputerSystem).Domain

Write-Host "Computer : $computer" -ForegroundColor White
Write-Host "Domain   : $domain" -ForegroundColor White
Write-Host ""

if (-not $domain -or $domain -eq $computer) {
    Write-Host "ERROR: This computer does not appear to be joined to a domain." -ForegroundColor Red
    Read-Host "`nPress ENTER to close"
    exit
}

# -------------------------------------------------
# Test basic network configuration
# -------------------------------------------------

Write-Host "Checking network configuration..." -ForegroundColor Yellow
ipconfig /all

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Finding Domain Controller..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

nltest /dsgetdc:$domain

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Could not locate a Domain Controller." -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - DNS is pointing to the wrong server"
    Write-Host "  - Network connection is unavailable"
    Write-Host "  - Domain Controller is unreachable"
    Write-Host "  - VPN is required"
    Write-Host "  - This is Safe Mode without Networking"
    Write-Host ""
    Write-Host "Current DNS configuration:" -ForegroundColor Cyan
    Get-DnsClientServerAddress -AddressFamily IPv4
    Write-Host ""

    Read-Host "Press ENTER to close"
    exit
}

Write-Host ""
Write-Host "Domain Controller found!" -ForegroundColor Green

# -------------------------------------------------
# Test secure channel
# -------------------------------------------------

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testing Secure Channel..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$secureChannel = Test-ComputerSecureChannel -Verbose

if ($secureChannel) {
    Write-Host ""
    Write-Host "SUCCESS: Secure channel is already healthy." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press ENTER to close"
    exit
}

Write-Host ""
Write-Host "Secure channel is BROKEN." -ForegroundColor Red
Write-Host ""
Write-Host "Attempting repair..." -ForegroundColor Yellow

# -------------------------------------------------
# Repair
# -------------------------------------------------

$credential = Get-Credential -Message "Enter DOMAIN credentials authorized to repair this computer"

if (-not $credential) {
    Write-Host ""
    Write-Host "No credentials supplied. Repair cancelled." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit
}

$result = Test-ComputerSecureChannel `
    -Repair `
    -Credential $credential `
    -Verbose

Write-Host ""

if ($result) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "       DOMAIN TRUST REPAIRED" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Verifying repair..." -ForegroundColor Yellow

    $verify = Test-ComputerSecureChannel -Verbose

    if ($verify) {
        Write-Host ""
        Write-Host "SUCCESS: Secure channel verified." -ForegroundColor Green
        Write-Host ""
        Write-Host "A restart is recommended." -ForegroundColor Yellow
        Write-Host ""
        $restart = Read-Host "Restart now? (Y/N)"

        if ($restart -eq "Y" -or $restart -eq "y") {
            Restart-Computer
        }
    }
    else {
        Write-Host ""
        Write-Host "WARNING: Repair reported success, but verification failed." -ForegroundColor Yellow
    }
}
else {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "       DOMAIN TRUST REPAIR FAILED" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "The computer account could not be repaired." -ForegroundColor Red
}

Write-Host ""
Read-Host "Press ENTER to close"
