function Start-SystemUpdates {
    $ModuleName = "PSWindowsUpdate"

    try {
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "       WINDOWS UPDATE PROCESS" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        # ---------------------------------------------------------
        # 1. Install NuGet provider
        # ---------------------------------------------------------
        Write-Host "[1/4] Checking NuGet provider..." -ForegroundColor Yellow

        Install-PackageProvider `
            -Name NuGet `
            -MinimumVersion 2.8.5.201 `
            -Force `
            -Confirm:$false `
            -ErrorAction SilentlyContinue | Out-Null

        # ---------------------------------------------------------
        # 2. Set PSGallery to Trusted
        # ---------------------------------------------------------
        Write-Host "[2/4] Checking PowerShell Gallery..." -ForegroundColor Yellow

        if (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue) {
            Set-PSRepository `
                -Name "PSGallery" `
                -InstallationPolicy Trusted `
                -ErrorAction SilentlyContinue
        }

        # ---------------------------------------------------------
        # 3. Install PSWindowsUpdate if needed
        # ---------------------------------------------------------
        Write-Host "[3/4] Checking PSWindowsUpdate module..." -ForegroundColor Yellow

        if (-not (Get-Module -ListAvailable $ModuleName)) {
            Write-Host "Installing PSWindowsUpdate..." -ForegroundColor Cyan

            Install-Module `
                $ModuleName `
                -Force `
                -Confirm:$false `
                -Scope AllUsers `
                -AllowClobber `
                -ErrorAction Stop
        }

        Import-Module $ModuleName -ErrorAction Stop

        # ---------------------------------------------------------
        # 4. Find available updates
        # ---------------------------------------------------------
        Write-Host ""
        Write-Host "[4/4] Checking for available updates..." -ForegroundColor Yellow
        Write-Host ""

        $Updates = @(Get-WindowsUpdate `
            -MicrosoftUpdate `
            -ErrorAction Stop)

        # ---------------------------------------------------------
        # No updates found
        # ---------------------------------------------------------
        if ($Updates.Count -eq 0) {
            Write-Host "No updates are available." -ForegroundColor Green
            Write-Host ""

            return
        }

        # ---------------------------------------------------------
        # Display queued updates
        # ---------------------------------------------------------
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "           UPDATES QUEUED" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        $Number = 1

        foreach ($Update in $Updates) {
            Write-Host "[$Number] $($Update.Title)" -ForegroundColor White

            if ($Update.KB) {
                Write-Host "     KB: $($Update.KB)" -ForegroundColor DarkGray
            }

            if ($Update.Size) {
                $SizeGB = [math]::Round($Update.Size / 1GB, 2)
                $SizeMB = [math]::Round($Update.Size / 1MB, 1)

                if ($SizeGB -ge 1) {
                    Write-Host "     Size: $SizeGB GB" -ForegroundColor DarkGray
                }
                else {
                    Write-Host "     Size: $SizeMB MB" -ForegroundColor DarkGray
                }
            }

            Write-Host ""

            $Number++
        }

        Write-Host "Total updates queued: $($Updates.Count)" -ForegroundColor Green
        Write-Host ""

        # ---------------------------------------------------------
        # Confirm before installation
        # ---------------------------------------------------------
        $Continue = Read-Host "Install these updates? (Y/N)"

        if ($Continue -notmatch "^[Yy]$") {
            Write-Host ""
            Write-Host "Update installation cancelled." -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "          INSTALLING UPDATES" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        # ---------------------------------------------------------
        # Install updates
        # ---------------------------------------------------------
        $Completed = 0
        $Total = $Updates.Count

        foreach ($Update in $Updates) {

            $Completed++

            $Title = $Update.Title

            if ($Title.Length -gt 90) {
                $DisplayTitle = $Title.Substring(0, 87) + "..."
            }
            else {
                $DisplayTitle = $Title
            }

            # Progress bar
            $Percent = [math]::Round((($Completed - 1) / $Total) * 100)

            Write-Progress `
                -Activity "Installing Windows Updates" `
                -Status "Working on update $Completed of $Total" `
                -CurrentOperation $DisplayTitle `
                -PercentComplete $Percent

            Write-Host ""
            Write-Host "---------------------------------------------" -ForegroundColor DarkGray
            Write-Host "Working on update $Completed of $Total" -ForegroundColor Cyan
            Write-Host $Title -ForegroundColor White

            if ($Update.KB) {
                Write-Host "KB: $($Update.KB)" -ForegroundColor DarkGray
            }

            Write-Host "---------------------------------------------" -ForegroundColor DarkGray

            try {
                # Install this specific update
                $Result = Get-WindowsUpdate `
                    -MicrosoftUpdate `
                    -KBArticleID $Update.KB `
                    -Install `
                    -AcceptAll `
                    -IgnoreReboot `
                    -ErrorAction Stop

                Write-Host "Completed: $Title" -ForegroundColor Green
            }
            catch {
                Write-Host "FAILED: $Title" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            }

            # Update progress after completion
            $Percent = [math]::Round(($Completed / $Total) * 100)

            Write-Progress `
                -Activity "Installing Windows Updates" `
                -Status "Completed $Completed of $Total" `
                -CurrentOperation $DisplayTitle `
                -PercentComplete $Percent
        }

        # Finish progress bar
        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Status "All updates processed" `
            -PercentComplete 100 `
            -Completed

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host "       WINDOWS UPDATE COMPLETE" -ForegroundColor Green
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Completed

        Write-Host ""
        Write-Host "Update process encountered an error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        throw
    }
}


function Add-ToDomain {
    param (
        [string]$Domain = "unit40.org",
        [string]$Username = "Techteam"
    )

    # Prompt user for password securely
    $Password = Read-Host `
        -Prompt "Enter domain password for $Username" `
        -AsSecureString

    $Credential = New-Object System.Management.Automation.PSCredential(
        "$Domain\$Username",
        $Password
    )

    # Join the domain and restart the computer
    Add-Computer `
        -DomainName $Domain `
        -Credential $Credential `
        -Restart `
        -Force
}


# ============================================================
# SCRIPT EXECUTION
# ============================================================

# 1. Run Windows Updates
Start-SystemUpdates

# 2. Add computer to domain and restart
Add-ToDomain
