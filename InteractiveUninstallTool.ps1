[CmdletBinding()]
param(

    [switch]$SkipGPResult,

    [switch]$Force,

    [string]$LogFile = "$env:TEMP\AppCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

)

#------------------------------------------------------------
# Script Variables
#------------------------------------------------------------

$script:Version = "3.0"

$script:Apps = @()

$script:SelectedApps = @()

$script:RemovedApps = @()

$script:FailedApps = @()

#------------------------------------------------------------
# Banner
#------------------------------------------------------------

function Show-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "      Interactive Application Cleanup Tool"
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version : $($script:Version)"
    Write-Host "Log File: $LogFile"
    Write-Host ""

}

#------------------------------------------------------------
# Logging
#------------------------------------------------------------

function Write-Log {

    param(
        [string]$Message
    )

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    "$TimeStamp  $Message" |
        Out-File `
            -FilePath $LogFile `
            -Append `
            -Encoding UTF8

}

#------------------------------------------------------------
# Console Output
#------------------------------------------------------------

function Write-Info {

    param([string]$Message)

    Write-Host "[INFO ] $Message" -ForegroundColor Cyan

    Write-Log "[INFO ] $Message"

}

function Write-Success {

    param([string]$Message)

    Write-Host "[ OK  ] $Message" -ForegroundColor Green

    Write-Log "[ OK  ] $Message"

}

function Write-WarningMessage {

    param([string]$Message)

    Write-Host "[WARN ] $Message" -ForegroundColor Yellow

    Write-Log "[WARN ] $Message"

}

function Write-ErrorMessage {

    param([string]$Message)

    Write-Host "[FAIL ] $Message" -ForegroundColor Red

    Write-Log "[FAIL ] $Message"

}

#------------------------------------------------------------
# Elevation
#------------------------------------------------------------

function Start-Elevation {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    if (!$Principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

        Write-Host ""
        Write-Host "Restarting as Administrator..." -ForegroundColor Yellow

        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""

        exit

    }

}

#------------------------------------------------------------
# GPResult
#------------------------------------------------------------

function Show-GPResult {

    if ($SkipGPResult) {

        return

    }

    Write-Info "Displaying Computer Group Policy..."

    gpresult /r /scope computer

    Pause

}

#------------------------------------------------------------
# Initialization
#------------------------------------------------------------

function Initialize-Script {

    Show-Banner

    Start-Elevation

    Write-Info "Starting Application Cleanup Tool"

    Write-Info "PowerShell Version $($PSVersionTable.PSVersion)"

    Show-GPResult

    Write-Success "Initialization Complete"

}

#------------------------------------------------------------
# Inventory Engine
#------------------------------------------------------------

function Get-InstalledApplications {

    Write-Info "Scanning installed applications..."

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Applications = foreach ($Path in $RegistryPaths) {

        if (!(Test-Path ($Path -replace "\\\*$",""))) {
            continue
        }

        Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue |
        Where-Object {

            $_.DisplayName

        } |
        ForEach-Object {

            $Guid = $null

            if ($_.PSChildName -match '^\{.*\}$') {

                $Guid = $_.PSChildName

            }

            [PSCustomObject]@{

                DisplayName = $_.DisplayName

                DisplayVersion = if ($_.DisplayVersion) {
                    $_.DisplayVersion.Trim()
                }
                else {
                    ""
                }

                Publisher = $_.Publisher

                InstallDate = $_.InstallDate

                InstallLocation = $_.InstallLocation

                InstallSource = $_.InstallSource

                EstimatedSize = $_.EstimatedSize

                QuietUninstallString = $_.QuietUninstallString

                UninstallString = $_.UninstallString

                GUID = $Guid

                RegistryKey = $_.PSPath

            }

        }

    }

    #
    # Remove duplicate registry entries
    #

    $Applications = $Applications |
        Sort-Object DisplayName,
                    DisplayVersion,
                    Publisher -Unique

    $script:Apps = $Applications

    Write-Success "$($script:Apps.Count) installed applications found."

    return $script:Apps

}

#------------------------------------------------------------
# Refresh Inventory
#------------------------------------------------------------

function Refresh-Inventory {

    $script:Apps = Get-InstalledApplications

}

#------------------------------------------------------------
# Display Inventory
#------------------------------------------------------------

function Show-Inventory {

    if ($script:Apps.Count -eq 0) {

        Write-WarningMessage "No installed applications found."

        return

    }

    $script:Apps |
        Sort-Object DisplayName |
        Select-Object `
            DisplayName,
            DisplayVersion,
            Publisher,
            InstallDate |
        Format-Table -AutoSize

}

#------------------------------------------------------------
# Search Applications
#------------------------------------------------------------

function Find-Applications {

    param(

        [Parameter(Mandatory)]

        [string]$Search

    )

    return $script:Apps |
        Where-Object {

            $_.DisplayName -like "*$Search*"

        } |
        Sort-Object DisplayName

}

#------------------------------------------------------------
# Out-GridView Selection
#------------------------------------------------------------

function Select-Applications {

    if (!(Get-Command Out-GridView -ErrorAction SilentlyContinue)) {

        Write-WarningMessage "Out-GridView is not installed."

        return

    }

    $Selected = $script:Apps |

        Sort-Object DisplayName,DisplayVersion |

        Select-Object `
            DisplayName,
            DisplayVersion,
            Publisher,
            InstallDate,
            QuietUninstallString,
            UninstallString,
            GUID,
            RegistryKey |

        Out-GridView `
            -Title "Select Applications To Remove (CTRL or SHIFT for Multiple)" `
            -OutputMode Multiple

    if (!$Selected) {

        Write-WarningMessage "Nothing selected."

        return

    }

    foreach ($Application in $Selected) {

        $AlreadyExists = $script:SelectedApps |

            Where-Object {

                $_.DisplayName -eq $Application.DisplayName -and
                $_.DisplayVersion -eq $Application.DisplayVersion

            }

        if (!$AlreadyExists) {

            $script:SelectedApps += $Application

        }

    }

    Write-Success "$($script:SelectedApps.Count) application(s) currently in queue."

}

#------------------------------------------------------------
# Show Queue
#------------------------------------------------------------

function Show-Queue {

    if ($script:SelectedApps.Count -eq 0) {

        Write-WarningMessage "Queue is empty."

        return

    }

    $script:SelectedApps |

        Sort-Object DisplayName |

        Select-Object `
            DisplayName,
            DisplayVersion,
            Publisher |

        Format-Table -AutoSize

}

#------------------------------------------------------------
# Clear Queue
#------------------------------------------------------------

function Clear-Queue {

    $script:SelectedApps = @()

    Write-Success "Removal queue cleared."

}

#------------------------------------------------------------
# Execute Uninstall Command
#------------------------------------------------------------

function Invoke-UninstallCommand {

    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    Write-Info "Executing uninstall command..."
    Write-Log "Command: $Command"

    #
    # Handle MSI installs separately
    #
    if ($Command -match '(?i)msiexec(\.exe)?') {

        if ($Command -match '\{[A-F0-9\-]+\}') {

            $ProductCode = $matches[0]

            Write-Info "Detected MSI Product"

            $Process = Start-Process `
                -FilePath "msiexec.exe" `
                -ArgumentList "/x $ProductCode /qn /norestart" `
                -PassThru `
                -Wait

            return $Process.ExitCode

        }

        Write-ErrorMessage "MSI command found but ProductCode was not."

        return -1

    }

    #
    # Execute EXE uninstall exactly as Windows registered it
    #
    $Process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList "/c",$Command `
        -Wait `
        -PassThru

    return $Process.ExitCode

}

#------------------------------------------------------------
# Verify Removal
#------------------------------------------------------------

function Test-ApplicationRemoved {

    param(
        [Parameter(Mandatory)]
        [psobject]$Application
    )

    Refresh-Inventory

    $Found = $script:Apps | Where-Object {

        $_.DisplayName -eq $Application.DisplayName -and
        $_.DisplayVersion -eq $Application.DisplayVersion

    }

    return ($null -eq $Found)

}

#------------------------------------------------------------
# Remove One Application
#------------------------------------------------------------

function Remove-Application {

    param(
        [Parameter(Mandatory)]
        [psobject]$Application
    )

    Write-Host ""
    Write-Host "========================================================"
    Write-Host "Removing:"
    Write-Host "   $($Application.DisplayName)"
    Write-Host "   Version $($Application.DisplayVersion)"
    Write-Host "========================================================"
    Write-Host ""

    $Command = $null

    if (![string]::IsNullOrWhiteSpace($Application.QuietUninstallString)) {

        $Command = $Application.QuietUninstallString

        Write-Info "Using QuietUninstallString"

    }
    else {

        $Command = $Application.UninstallString

        Write-Info "Using UninstallString"

    }

    if ([string]::IsNullOrWhiteSpace($Command)) {

        Write-ErrorMessage "No uninstall command exists."

        $script:FailedApps += $Application

        return

    }

    $ExitCode = Invoke-UninstallCommand $Command

    switch ($ExitCode) {

        0 {

            if (Test-ApplicationRemoved $Application) {

                Write-Success "Verified Removed"

                $script:RemovedApps += $Application

            }
            else {

                Write-WarningMessage "Installer returned success but application still exists."

                $script:FailedApps += $Application

            }

        }

        1605 {

            Write-WarningMessage "Application already removed."

            $script:RemovedApps += $Application

        }

        1614 {

            Write-WarningMessage "Product already uninstalled."

            $script:RemovedApps += $Application

        }

        1641 {

            Write-WarningMessage "Restart initiated."

            $script:RemovedApps += $Application

        }

        3010 {

            Write-WarningMessage "Restart required."

            $script:RemovedApps += $Application

        }

        default {

            Write-ErrorMessage "Exit Code $ExitCode"

            $script:FailedApps += $Application

        }

    }

}

#------------------------------------------------------------
# Start Uninstall
#------------------------------------------------------------

function Start-Uninstall {

    if ($script:SelectedApps.Count -eq 0) {

        Write-WarningMessage "No applications selected."

        Pause

        return

    }

    Clear-Host

    Write-Host ""
    Write-Host "Applications queued for removal"
    Write-Host "======================================================"

    $script:SelectedApps |
        Sort-Object DisplayName |
        Format-Table DisplayName,DisplayVersion -AutoSize

    Write-Host ""

    if (-not $Force) {

        $Answer = Read-Host "Continue? (Y/N)"

        if ($Answer.ToUpper() -ne "Y") {

            return

        }

    }

    $Total = $script:SelectedApps.Count
    $Current = 0

    foreach ($Application in $script:SelectedApps) {

        $Current++

        Write-Progress `
            -Activity "Removing Applications" `
            -Status "$Current of $Total" `
            -PercentComplete (($Current / $Total) * 100)

        Remove-Application $Application

    }

    Write-Progress `
        -Activity "Removing Applications" `
        -Completed

    Write-Host ""
    Write-Success "$($script:RemovedApps.Count) application(s) removed."
    Write-WarningMessage "$($script:FailedApps.Count) failed."

    Pause

}

#------------------------------------------------------------
# Execute Uninstall Command
#------------------------------------------------------------

function Invoke-UninstallCommand {

    param(
        [Parameter(Mandatory)]
        [string]$Command
    )

    Write-Info "Executing uninstall command..."
    Write-Log "Command: $Command"

    #
    # Handle MSI installs separately
    #
    if ($Command -match '(?i)msiexec(\.exe)?') {

        if ($Command -match '\{[A-F0-9\-]+\}') {

            $ProductCode = $matches[0]

            Write-Info "Detected MSI Product"

            $Process = Start-Process `
                -FilePath "msiexec.exe" `
                -ArgumentList "/x $ProductCode /qn /norestart" `
                -PassThru `
                -Wait

            return $Process.ExitCode

        }

        Write-ErrorMessage "MSI command found but ProductCode was not."

        return -1

    }

    #
    # Execute EXE uninstall exactly as Windows registered it
    #
    $Process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList "/c",$Command `
        -Wait `
        -PassThru

    return $Process.ExitCode

}

#------------------------------------------------------------
# Verify Removal
#------------------------------------------------------------

function Test-ApplicationRemoved {

    param(
        [Parameter(Mandatory)]
        [psobject]$Application
    )

    Refresh-Inventory

    $Found = $script:Apps | Where-Object {

        $_.DisplayName -eq $Application.DisplayName -and
        $_.DisplayVersion -eq $Application.DisplayVersion

    }

    return ($null -eq $Found)

}

#------------------------------------------------------------
# Remove One Application
#------------------------------------------------------------

function Remove-Application {

    param(
        [Parameter(Mandatory)]
        [psobject]$Application
    )

    Write-Host ""
    Write-Host "========================================================"
    Write-Host "Removing:"
    Write-Host "   $($Application.DisplayName)"
    Write-Host "   Version $($Application.DisplayVersion)"
    Write-Host "========================================================"
    Write-Host ""

    $Command = $null

    if (![string]::IsNullOrWhiteSpace($Application.QuietUninstallString)) {

        $Command = $Application.QuietUninstallString

        Write-Info "Using QuietUninstallString"

    }
    else {

        $Command = $Application.UninstallString

        Write-Info "Using UninstallString"

    }

    if ([string]::IsNullOrWhiteSpace($Command)) {

        Write-ErrorMessage "No uninstall command exists."

        $script:FailedApps += $Application

        return

    }

    $ExitCode = Invoke-UninstallCommand $Command

    switch ($ExitCode) {

        0 {

            if (Test-ApplicationRemoved $Application) {

                Write-Success "Verified Removed"

                $script:RemovedApps += $Application

            }
            else {

                Write-WarningMessage "Installer returned success but application still exists."

                $script:FailedApps += $Application

            }

        }

        1605 {

            Write-WarningMessage "Application already removed."

            $script:RemovedApps += $Application

        }

        1614 {

            Write-WarningMessage "Product already uninstalled."

            $script:RemovedApps += $Application

        }

        1641 {

            Write-WarningMessage "Restart initiated."

            $script:RemovedApps += $Application

        }

        3010 {

            Write-WarningMessage "Restart required."

            $script:RemovedApps += $Application

        }

        default {

            Write-ErrorMessage "Exit Code $ExitCode"

            $script:FailedApps += $Application

        }

    }

}

#------------------------------------------------------------
# Start Uninstall
#------------------------------------------------------------

function Start-Uninstall {

    if ($script:SelectedApps.Count -eq 0) {

        Write-WarningMessage "No applications selected."

        Pause

        return

    }

    Clear-Host

    Write-Host ""
    Write-Host "Applications queued for removal"
    Write-Host "======================================================"

    $script:SelectedApps |
        Sort-Object DisplayName |
        Format-Table DisplayName,DisplayVersion -AutoSize

    Write-Host ""

    if (-not $Force) {

        $Answer = Read-Host "Continue? (Y/N)"

        if ($Answer.ToUpper() -ne "Y") {

            return

        }

    }

    $Total = $script:SelectedApps.Count
    $Current = 0

    foreach ($Application in $script:SelectedApps) {

        $Current++

        Write-Progress `
            -Activity "Removing Applications" `
            -Status "$Current of $Total" `
            -PercentComplete (($Current / $Total) * 100)

        Remove-Application $Application

    }

    Write-Progress `
        -Activity "Removing Applications" `
        -Completed

    Write-Host ""
    Write-Success "$($script:RemovedApps.Count) application(s) removed."
    Write-WarningMessage "$($script:FailedApps.Count) failed."

    Pause

}

#------------------------------------------------------------
# Export Results
#------------------------------------------------------------

function Export-Results {

    $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $ExportFolder = Join-Path $env:TEMP "AppCleanup"

    if (!(Test-Path $ExportFolder)) {

        New-Item `
            -ItemType Directory `
            -Path $ExportFolder | Out-Null

    }

    $InstalledFile = Join-Path $ExportFolder "InstalledApps_$TimeStamp.csv"

    $RemovedFile = Join-Path $ExportFolder "RemovedApps_$TimeStamp.csv"

    $FailedFile = Join-Path $ExportFolder "FailedApps_$TimeStamp.csv"

    $script:Apps |
        Sort-Object DisplayName |
        Export-Csv `
            -Path $InstalledFile `
            -NoTypeInformation `
            -Encoding UTF8

    $script:RemovedApps |
        Sort-Object DisplayName |
        Export-Csv `
            -Path $RemovedFile `
            -NoTypeInformation `
            -Encoding UTF8

    $script:FailedApps |
        Sort-Object DisplayName |
        Export-Csv `
            -Path $FailedFile `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Success "Reports exported."

    Write-Host ""
    Write-Host "Installed : $InstalledFile"
    Write-Host "Removed   : $RemovedFile"
    Write-Host "Failed    : $FailedFile"
    Write-Host ""

}

#------------------------------------------------------------
# Show Summary
#------------------------------------------------------------

function Show-Summary {

    Clear-Host

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "                Cleanup Summary"
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host ("Installed Applications : {0}" -f $script:Apps.Count)

    Write-Host ("Removed Applications   : {0}" -f $script:RemovedApps.Count)

    Write-Host ("Failed Applications    : {0}" -f $script:FailedApps.Count)

    Write-Host ""

    if ($script:RemovedApps.Count -gt 0) {

        Write-Host "Removed Applications"
        Write-Host "--------------------"

        $script:RemovedApps |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                DisplayVersion `
                -AutoSize

    }

    if ($script:FailedApps.Count -gt 0) {

        Write-Host ""
        Write-Host "Failed Applications"
        Write-Host "-------------------"

        $script:FailedApps |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                DisplayVersion `
                -AutoSize

    }

}

#------------------------------------------------------------
# Verify Installed Applications
#------------------------------------------------------------

function Show-RemainingApplications {

    Refresh-Inventory

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {

        $script:Apps |
            Sort-Object DisplayName |
            Select-Object `
                DisplayName,
                DisplayVersion,
                Publisher,
                InstallDate |
            Out-GridView `
                -Title "Applications Remaining"

    }
    else {

        Show-Inventory

    }

}

#------------------------------------------------------------
# End Session
#------------------------------------------------------------

function Complete-Session {

    Write-Host ""

    Write-Info "Refreshing inventory..."

    Refresh-Inventory

    Export-Results

    Show-Summary

    Show-RemainingApplications

    Write-Host ""

    Write-Success "Cleanup complete."

    Write-Host ""

    Write-Host "Log File"

    Write-Host "--------"

    Write-Host $LogFile

    Write-Host ""

    Pause

}

#------------------------------------------------------------
# Reset Session
#------------------------------------------------------------

function Reset-Session {

    $script:SelectedApps = @()

    $script:RemovedApps = @()

    $script:FailedApps = @()

    Write-Success "Session reset."

}

#------------------------------------------------------------
# Remove Items From Queue
#------------------------------------------------------------

function Remove-FromQueue {

    if ($script:SelectedApps.Count -eq 0) {

        Write-WarningMessage "Removal queue is empty."

        Pause

        return

    }

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {

        $Remove = $script:SelectedApps |
            Sort-Object DisplayName |
            Select-Object `
                DisplayName,
                DisplayVersion,
                Publisher |
            Out-GridView `
                -Title "Select Applications To REMOVE From Queue" `
                -OutputMode Multiple

        if (!$Remove) {

            return

        }

        foreach ($Item in $Remove) {

            $script:SelectedApps = $script:SelectedApps | Where-Object {

                !(
                    $_.DisplayName -eq $Item.DisplayName -and
                    $_.DisplayVersion -eq $Item.DisplayVersion
                )

            }

        }

        Write-Success "Queue updated."

        return

    }

    Show-Queue

    Pause

}

#------------------------------------------------------------
# Search Installed Applications
#------------------------------------------------------------

function Search-Applications {

    $Search = Read-Host "Search"

    if ([string]::IsNullOrWhiteSpace($Search)) {

        return

    }

    $Results = $script:Apps |
        Where-Object {

            $_.DisplayName -like "*$Search*" -or
            $_.Publisher -like "*$Search*" -or
            $_.DisplayVersion -like "*$Search*"

        } |
        Sort-Object DisplayName

    if ($Results.Count -eq 0) {

        Write-WarningMessage "Nothing found."

        Pause

        return

    }

    if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {

        $Selection = $Results |
            Out-GridView `
                -Title "Search Results" `
                -OutputMode Multiple

        if ($Selection) {

            foreach ($App in $Selection) {

                if (-not ($script:SelectedApps | Where-Object {

                    $_.DisplayName -eq $App.DisplayName -and
                    $_.DisplayVersion -eq $App.DisplayVersion

                })) {

                    $script:SelectedApps += $App

                }

            }

            Write-Success "Application(s) added."

        }

    }

    else {

        $Results |
            Format-Table `
                DisplayName,
                DisplayVersion,
                Publisher `
                -AutoSize

        Pause

    }

}

#------------------------------------------------------------
# Show Statistics
#------------------------------------------------------------

function Show-Statistics {

    Clear-Host

    Write-Host ""

    Write-Host "Application Cleanup Statistics"

    Write-Host "===================================================="

    Write-Host ""

    Write-Host ("Installed Applications : {0}" -f $script:Apps.Count)

    Write-Host ("Queued                : {0}" -f $script:SelectedApps.Count)

    Write-Host ("Removed               : {0}" -f $script:RemovedApps.Count)

    Write-Host ("Failed                : {0}" -f $script:FailedApps.Count)

    Write-Host ""

    Pause

}

#------------------------------------------------------------
# Update Main Menu
#------------------------------------------------------------

function Show-MainMenu {

    do {

        Clear-Host

        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Interactive Application Cleanup Tool v3"
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host ("Installed : {0}" -f $script:Apps.Count)
        Write-Host ("Queue     : {0}" -f $script:SelectedApps.Count)
        Write-Host ("Removed   : {0}" -f $script:RemovedApps.Count)
        Write-Host ("Failed    : {0}" -f $script:FailedApps.Count)

        Write-Host ""

        Write-Host "1  Refresh Inventory"
        Write-Host "2  View Installed Applications"
        Write-Host "3  Search Applications"
        Write-Host "4  Select Applications (Grid)"
        Write-Host "5  View Queue"
        Write-Host "6  Remove From Queue"
        Write-Host "7  Clear Queue"
        Write-Host "8  Start Uninstall"
        Write-Host "9  Statistics"
        Write-Host "10 Exit"

        Write-Host ""

        switch (Read-Host "Selection") {

            "1" {

                Refresh-Inventory

                Pause

            }

            "2" {

                Show-RemainingApplications

            }

            "3" {

                Search-Applications

            }

            "4" {

                Select-Applications

            }

            "5" {

                Show-Queue

                Pause

            }

            "6" {

                Remove-FromQueue

            }

            "7" {

                Clear-Queue

                Pause

            }

"8" {

    Start-Uninstall

    if ($script:RemovedApps.Count -gt 0 -or $script:FailedApps.Count -gt 0) {

        Complete-Session

    }

}
            "9" {

                Show-Statistics

            }

            "10" {

                return

            }

        }

    } while ($true)

}

#============================================================
# Program Startup
#============================================================

try {

    #
    # Initialize the application
    #
    Initialize-Script

    #
    # Build initial inventory
    #
    Refresh-Inventory

    #
    # Display inventory count
    #
    Write-Info "$($script:Apps.Count) installed applications detected."

    #
    # Start interactive menu
    #
    Show-MainMenu

}
catch {

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "Fatal Error"
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host ""

    Write-Host $_.Exception.Message -ForegroundColor Yellow

    Write-Host ""

    Write-Log $_

}
finally {

    Write-Host ""

    Write-Info "Application Cleanup Tool Closed."

    Write-Log "Session Ended"

}