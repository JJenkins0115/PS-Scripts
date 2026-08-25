# ============================================================
# Script:        NetFix.ps1
# Repository:    U40Tech / Tools
# Description:   Automated Network Adapter & TCP/IP Repair Tool
# Compatibility: PowerShell 5.1+, Elevated Context Required
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

Write-Host "============================================================"
Write-Host "               U40Tech - Network Stack Repair               "
Write-Host "============================================================"
Write-Host ""

try {
    # 1. Flush DNS Resolver Cache
    Write-Host "[>] Clearing local DNS resolver cache..." -ForegroundColor Cyan
    Clear-DnsClientCache
    Write-Host "[+] DNS client cache flushed successfully."

    # 2. DHCP Lease Reset
    Write-Host ""
    Write-Host "[>] Releasing active DHCP IP leases..." -ForegroundColor Cyan
    $Null = Start-Process -FilePath "ipconfig.exe" -ArgumentList "/release" -NoNewWindow -Wait

    Write-Host "[>] Renewing DHCP IP address leases..." -ForegroundColor Cyan
    $Null = Start-Process -FilePath "ipconfig.exe" -ArgumentList "/renew" -NoNewWindow -Wait
    Write-Host "[+] IP address lease renewal complete."

    # 3. NetBIOS Name Cache Reset
    Write-Host ""
    Write-Host "[>] Purging NetBIOS name cache..." -ForegroundColor Cyan
    $Null = Start-Process -FilePath "nbtstat.exe" -ArgumentList "-R" -NoNewWindow -Wait
    Write-Host "[+] NetBIOS cache reloaded."

    # 4. Winsock & IP Catalog Reset
    Write-Host ""
    Write-Host "[>] Resetting Winsock catalog sockets..." -ForegroundColor Cyan
    $Null = Start-Process -FilePath "netsh.exe" -ArgumentList "winsock reset" -NoNewWindow -Wait
    Write-Host "[+] Winsock catalog reset successfully."

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[+] Network stack repair complete!"
    Write-Host "[!] Note: A restart may be necessary if physical links fail."
    Write-Host "============================================================"
}
catch {
    Write-Host ""
    Write-Host "[-] Network Repair Error: $($_.Exception.Message)"
    exit 1
}
