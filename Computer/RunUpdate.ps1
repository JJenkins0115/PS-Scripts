function Start-SystemUpdates {

    $ModuleName = "PSWindowsUpdate"

    try {

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "          WINDOWS UPDATE PROCESS" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""


        # ---------------------------------------------------------
        # 1. Install NuGet
        # ---------------------------------------------------------
        Write-Host "[1/4] Checking NuGet provider..." -ForegroundColor Yellow

        Install-PackageProvider `
            -Name NuGet `
            -MinimumVersion 2.8.5.201 `
            -Force `
            -Confirm:$false `
            -ErrorAction SilentlyContinue |
            Out-Null


        # ---------------------------------------------------------
        # 2. Trust PSGallery
        # ---------------------------------------------------------
        Write-Host "[2/4] Checking PowerShell Gallery..." -ForegroundColor Yellow

        if (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue) {

            Set-PSRepository `
                -Name "PSGallery" `
                -InstallationPolicy Trusted `
                -ErrorAction SilentlyContinue
        }


        # ---------------------------------------------------------
        # 3. Install PSWindowsUpdate
        # ---------------------------------------------------------
        Write-Host "[3/4] Checking PSWindowsUpdate..." -ForegroundColor Yellow

        if (-not (Get-Module -ListAvailable -Name $ModuleName)) {

            Write-Host "Installing PSWindowsUpdate..." -ForegroundColor Cyan

            Install-Module `
                -Name $ModuleName `
                -Force `
                -Confirm:$false `
                -Scope AllUsers `
                -AllowClobber `
                -ErrorAction Stop
        }

        Import-Module $ModuleName -ErrorAction Stop


        # ---------------------------------------------------------
        # 4. Scan for updates
        # ---------------------------------------------------------
        Write-Host "[4/4] Checking Microsoft Update..." -ForegroundColor Yellow
        Write-Host ""

        $Updates = @(
            Get-WindowsUpdate `
                -MicrosoftUpdate `
                -ErrorAction Stop
        )


        # ---------------------------------------------------------
        # No updates
        # ---------------------------------------------------------
        if ($Updates.Count -eq 0) {

            Write-Host ""
            Write-Host "No updates are currently available." `
                -ForegroundColor Green

            Write-Host ""

            return $false
        }


        # ---------------------------------------------------------
        # Display queued updates
        # ---------------------------------------------------------
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "            UPDATES QUEUED" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        $Number = 1

        foreach ($Update in $Updates) {

            Write-Host "[$Number] $($Update.Title)" `
                -ForegroundColor White


            if ($Update.KB) {

                $KBText = @($Update.KB) -join ", "

                Write-Host "     KB: $KBText" `
                    -ForegroundColor DarkGray
            }


            # -----------------------------------------------------
            # Safely handle Size
            # -----------------------------------------------------
            if ($null -ne $Update.Size) {

                try {

                    $Sizes = @(
                        $Update.Size |
                        ForEach-Object {

                            if ($_ -is [int64] -or
                                $_ -is [int32] -or
                                $_ -is [double] -or
                                $_ -is [decimal]) {

                                [double]$_
                            }
                            elseif ($_ -as [double]) {

                                [double]$_
                            }
                        }
                    )

                    if ($Sizes.Count -gt 0) {

                        $TotalSize = ($Sizes | Measure-Object -Sum).Sum

                        if ($TotalSize -gt 0) {

                            $SizeMB = [math]::Round(
                                ($TotalSize / 1MB),
                                1
                            )

                            Write-Host "     Size: $SizeMB MB" `
                                -ForegroundColor DarkGray
                        }
                    }
                }
                catch {
                    # Ignore invalid size information
                }
            }


            # -----------------------------------------------------
            # Detect driver
            # -----------------------------------------------------
            if ($Update.Driver -eq $true) {

                Write-Host "     Type: DRIVER" `
                    -ForegroundColor Yellow
            }


            Write-Host ""

            $Number++
        }


        Write-Host "Total updates queued: $($Updates.Count)" `
            -ForegroundColor Green

        Write-Host ""


        # ---------------------------------------------------------
        # Install updates
        #
        # IMPORTANT:
        # Do NOT install each update individually by KB.
        # This allows driver updates without KB numbers to work.
        #
        # -IgnoreReboot prevents Windows Update from rebooting
        # before all updates have finished processing.
        # ---------------------------------------------------------
        Write-Host "=============================================" `
            -ForegroundColor Cyan

        Write-Host "          INSTALLING UPDATES" `
            -ForegroundColor Cyan

        Write-Host "=============================================" `
            -ForegroundColor Cyan

        Write-Host ""


        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Status "Starting update installation..." `
            -PercentComplete 0


        Get-WindowsUpdate `
            -MicrosoftUpdate `
            -AcceptAll `
            -Install `
            -IgnoreReboot `
            -Verbose `
            -ErrorAction Stop


        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Status "Update installation complete" `
            -PercentComplete 100


        Start-Sleep -Seconds 1


        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Completed


        # ---------------------------------------------------------
        # Check whether Windows requires reboot
        # ---------------------------------------------------------
        $RebootRequired = $false


        $RebootKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        )


        foreach ($Key in $RebootKeys) {

            if (Test-Path $Key) {

                $RebootRequired = $true
                break
            }
        }


        # ---------------------------------------------------------
        # Check Windows Update reboot status if available
        # ---------------------------------------------------------
        try {

            $SystemInfo = Get-WURebootStatus -ErrorAction SilentlyContinue

            if ($SystemInfo -and $SystemInfo.RebootRequired) {

                $RebootRequired = $true
            }
        }
        catch {
            # Registry checks above are sufficient if this command
            # is unavailable in the installed PSWindowsUpdate version.
        }


        # ---------------------------------------------------------
        # Update process complete
        # ---------------------------------------------------------
        Write-Host ""
        Write-Host "=============================================" `
            -ForegroundColor Green

        Write-Host "          UPDATE PROCESS COMPLETE" `
            -ForegroundColor Green

        Write-Host "=============================================" `
            -ForegroundColor Green

        Write-Host ""


        # ---------------------------------------------------------
        # Reboot if required
        # ---------------------------------------------------------
        if ($RebootRequired) {

            Write-Host "A restart is required to finalize updates." `
                -ForegroundColor Yellow

            Write-Host ""

            Write-Host "The computer will restart automatically." `
                -ForegroundColor Yellow

            Write-Host ""


            # -----------------------------------------------------
            # 10-second countdown
            # -----------------------------------------------------
            for ($Seconds = 10; $Seconds -gt 0; $Seconds--) {

                Write-Host "`rRestarting in $Seconds seconds... " `
                    -NoNewline `
                    -ForegroundColor Yellow

                Start-Sleep -Seconds 1
            }


            Write-Host ""
            Write-Host ""

            Write-Host "Restarting computer..." `
                -ForegroundColor Cyan

            Write-Host ""


            # -----------------------------------------------------
            # Restart computer
            # -----------------------------------------------------
            Restart-Computer -Force


            # This normally will never execute because the system
            # will restart.
            return $true
        }


        # ---------------------------------------------------------
        # No reboot required
        # ---------------------------------------------------------
        Write-Host "No restart is currently required." `
            -ForegroundColor Green

        Write-Host ""

        return $false
    }


    catch {

        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Completed


        Write-Host ""
        Write-Host "=============================================" `
            -ForegroundColor Red

        Write-Host "       WINDOWS UPDATE ENCOUNTERED AN ERROR" `
            -ForegroundColor Red

        Write-Host "=============================================" `
            -ForegroundColor Red

        Write-Host ""

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        Write-Host ""

        return $false
    }
}

Start-SystemUpdates
