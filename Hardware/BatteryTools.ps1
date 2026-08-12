# Auto-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator..."
    Start-Process powershell "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host "HP ProBook x360 Battery and System Tools"
Write-Host ""


# FUNCTIONS

function BatteryReport {
    Write-Host "Generating battery report..."
    powercfg /batteryreport /output "$env:USERPROFILE\Desktop\battery-report.html"
    Write-Host "Battery report saved to Desktop."
}

function EnergyReport {
    Write-Host "Running energy efficiency scan..."
    powercfg /energy /output "$env:USERPROFILE\Desktop\energy-report.html"
    Write-Host "Energy report saved to Desktop."
}

function MonitorCPU {
    Write-Host "Live CPU Monitor (CTRL+C to stop)"
    while ($true) {
        Clear-Host
        Get-Process |
            Sort-Object CPU -Descending |
            Select-Object -First 10 ProcessName, Id, CPU, PM |
            Format-Table -AutoSize
        Start-Sleep 2
    }
}

function MonitorPowerUsage {
    Write-Host "Live PowerUsage Monitor (CTRL+C to stop)"
    while ($true) {
        Clear-Host
        Get-Process |
            Where-Object { $null -ne $_.PowerUsage } |
            Sort-Object PowerUsage -Descending |
            Select-Object -First 10 ProcessName, Id, PowerUsage |
            Format-Table -AutoSize
        Start-Sleep 3
    }
}g

function BatteryStatus {
    Write-Host "Current Battery Status:"
    Get-CimInstance Win32_Battery |
        Select-Object Name, BatteryStatus, EstimatedChargeRemaining, EstimatedRunTime |
        Format-Table -AutoSize
}

function ExitScript {
    Write-Host "Exiting script."
    exit
}


# MENU

function Menu {
    Write-Host ""
    Write-Host "1) Generate Battery Report"
    Write-Host "2) Run Energy Efficiency Scan"
    Write-Host "3) Monitor CPU Usage (Live)"
    Write-Host "4) Monitor Power Usage (Live)"
    Write-Host "5) Show Battery Status"
    Write-Host "0) Exit"
    Write-Host ""
}


# MAIN LOOP

do {
    Menu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        "1" { BatteryReport }
        "2" { EnergyReport }
        "3" { MonitorCPU }
        "4" { MonitorPowerUsage }
        "5" { BatteryStatus }
        "0" { ExitScript }
        default { Write-Host "Invalid selection." }
    }

    Write-Host ""
    Pause
} while ($true)
