Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "          NewCompV2  11:56   " -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

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

                    # Convert any array of sizes into numeric values
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
        # ---------------------------------------------------------
        Write-Host "=============================================" `
            -ForegroundColor Cyan

        Write-Host "          INSTALLING UPDATES" `
            -ForegroundColor Cyan

        Write-Host "=============================================" `
            -ForegroundColor Cyan

        Write-Host ""


        # Start a simple overall progress indicator
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


        Write-Host ""
        Write-Host "=============================================" `
            -ForegroundColor Green

        Write-Host "          UPDATE PROCESS COMPLETE" `
            -ForegroundColor Green

        Write-Host "=============================================" `
            -ForegroundColor Green

        Write-Host ""


        if ($RebootRequired) {

            Write-Host "A restart is required to finalize updates." `
                -ForegroundColor Yellow

        }
        else {

            Write-Host "No restart is currently required." `
                -ForegroundColor Green
        }

        Write-Host ""


        return $RebootRequired
    }
    catch {

        Write-Progress `
            -Activity "Installing Windows Updates" `
            -Completed


        Write-Host ""
        Write-Host "Windows Update encountered an error:" `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        Write-Host ""


        return $false
    }
}


function Add-ToDomain {

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "        ACTIVE DIRECTORY DISCOVERY" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""


    # ---------------------------------------------------------
    # Get DNS servers
    # ---------------------------------------------------------
    $DnsServers = @(
        Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object {
            $_.ServerAddresses
        } |
        ForEach-Object {
            $_.ServerAddresses
        } |
        Sort-Object -Unique
    )


    if ($DnsServers.Count -eq 0) {

        Write-Host "No DNS servers were found." `
            -ForegroundColor Red

        return $false
    }


    Write-Host "DNS servers found:" -ForegroundColor Yellow

    foreach ($Dns in $DnsServers) {
        Write-Host "  $Dns" -ForegroundColor Gray
    }

    Write-Host ""


    # ---------------------------------------------------------
    # Get DNS suffixes
    # ---------------------------------------------------------
    $DnsSuffixes = @(
        Get-DnsClient |
        Where-Object {
            $_.ConnectionSpecificSuffix
        } |
        Select-Object -ExpandProperty ConnectionSpecificSuffix
    )

    $DnsSuffixes = @(
        $DnsSuffixes |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object -Unique
    )


    # ---------------------------------------------------------
    # Find Active Directory domains
    # ---------------------------------------------------------
    $FoundDomains = @()


    foreach ($Dns in $DnsServers) {

        Write-Host "Searching DNS server $Dns..." `
            -ForegroundColor Cyan


        foreach ($Suffix in $DnsSuffixes) {

            Write-Host "  Checking $Suffix..." `
                -ForegroundColor DarkGray

            try {

                $LDAPRecords = Resolve-DnsName `
                    "_ldap._tcp.dc._msdcs.$Suffix" `
                    -Type SRV `
                    -Server $Dns `
                    -ErrorAction Stop


                if ($LDAPRecords) {

                    Write-Host "  Active Directory found!" `
                        -ForegroundColor Green


                    if ($Suffix -notin $FoundDomains) {
                        $FoundDomains += $Suffix
                    }


                    foreach ($Record in $LDAPRecords) {

                        if ($Record.NameTarget) {

                            Write-Host `
                                "    Domain Controller: $($Record.NameTarget)" `
                                -ForegroundColor Gray
                        }
                    }
                }
            }
            catch {
                # No AD record for this suffix
            }
        }
    }


    # ---------------------------------------------------------
    # Reverse DNS fallback
    # ---------------------------------------------------------
    if ($FoundDomains.Count -eq 0) {

        Write-Host ""
        Write-Host "No domain found from DNS suffixes." `
            -ForegroundColor Yellow

        Write-Host "Trying reverse DNS discovery..." `
            -ForegroundColor Cyan


        foreach ($Dns in $DnsServers) {

            try {

                $Reverse = Resolve-DnsName `
                    -Name $Dns `
                    -Type PTR `
                    -ErrorAction Stop


                foreach ($Record in $Reverse) {

                    if ($Record.NameHost) {

                        $Hostname = $Record.NameHost.TrimEnd(".")


                        Write-Host `
                            "DNS server hostname: $Hostname" `
                            -ForegroundColor Gray


                        $Parts = $Hostname.Split(".")


                        if ($Parts.Count -ge 2) {

                            $PossibleDomain = (
                                $Parts[1..($Parts.Count - 1)] -join "."
                            )


                            Write-Host `
                                "Testing possible domain: $PossibleDomain" `
                                -ForegroundColor Cyan


                            try {

                                $LDAPRecords = Resolve-DnsName `
                                    "_ldap._tcp.dc._msdcs.$PossibleDomain" `
                                    -Type SRV `
                                    -Server $Dns `
                                    -ErrorAction Stop


                                if ($LDAPRecords) {

                                    Write-Host `
                                        "Active Directory found!" `
                                        -ForegroundColor Green


                                    if ($PossibleDomain -notin $FoundDomains) {
                                        $FoundDomains += $PossibleDomain
                                    }
                                }
                            }
                            catch {
                                # Not an AD domain
                            }
                        }
                    }
                }
            }
            catch {
                # Reverse lookup unavailable
            }
        }
    }


    # ---------------------------------------------------------
    # No domain found
    # ---------------------------------------------------------
    if ($FoundDomains.Count -eq 0) {

        Write-Host ""
        Write-Host "No Active Directory domain was found." `
            -ForegroundColor Red

        Write-Host ""

        return $false
    }


    $FoundDomains = @(
        $FoundDomains |
        Sort-Object -Unique
    )


    # ---------------------------------------------------------
    # Select domain
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "=============================================" `
        -ForegroundColor Green

    Write-Host "          DOMAINS FOUND" `
        -ForegroundColor Green

    Write-Host "=============================================" `
        -ForegroundColor Green

    Write-Host ""


    for ($i = 0; $i -lt $FoundDomains.Count; $i++) {

        Write-Host "[$($i + 1)] $($FoundDomains[$i])" `
            -ForegroundColor White
    }

    Write-Host ""


    if ($FoundDomains.Count -eq 1) {

        $Domain = $FoundDomains[0]

        Write-Host "Domain automatically selected: $Domain" `
            -ForegroundColor Green
    }
    else {

        do {

            $Selection = Read-Host "Select the domain to join"

            $SelectionNumber = 0

            if (
                [int]::TryParse(
                    $Selection,
                    [ref]$SelectionNumber
                ) -and
                $SelectionNumber -ge 1 -and
                $SelectionNumber -le $FoundDomains.Count
            ) {

                $Domain = $FoundDomains[$SelectionNumber - 1]

                break
            }

            Write-Host "Invalid selection." `
                -ForegroundColor Red

        } while ($true)
    }


    # ---------------------------------------------------------
    # Username
    # ---------------------------------------------------------
    Write-Host ""

    $Username = Read-Host `
        "Enter domain username [Techteam]"

    if ([string]::IsNullOrWhiteSpace($Username)) {
        $Username = "Techteam"
    }


    # ---------------------------------------------------------
    # Password
    # ---------------------------------------------------------
    $Password = Read-Host `
        -Prompt "Enter domain password for $Username" `
        -AsSecureString


    $Credential = New-Object `
        System.Management.Automation.PSCredential(
            "$Domain\$Username",
            $Password
        )


    # ---------------------------------------------------------
    # Confirm
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "=============================================" `
        -ForegroundColor Cyan

    Write-Host "          DOMAIN JOIN CONFIRMATION" `
        -ForegroundColor Cyan

    Write-Host "=============================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Domain:   $Domain" -ForegroundColor White
    Write-Host "Username: $Username" -ForegroundColor White

    Write-Host ""


    $Confirm = Read-Host `
        "Join this computer to $Domain? (Y/N)"


    if ($Confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host "Domain join cancelled." `
            -ForegroundColor Yellow

        return $false
    }


    # ---------------------------------------------------------
    # Join domain WITHOUT restarting
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "Joining $Domain..." `
        -ForegroundColor Yellow

    try {

        Add-Computer `
            -DomainName $Domain `
            -Credential $Credential `
            -Force `
            -ErrorAction Stop


        Write-Host ""
        Write-Host "Computer successfully joined to $Domain." `
            -ForegroundColor Green

        Write-Host "The computer will NOT restart yet." `
            -ForegroundColor Yellow

        return $true
    }
    catch {

        Write-Host ""
        Write-Host "Failed to join domain." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        return $false
    }
}


# =============================================================
# MAIN SCRIPT
# =============================================================

# -------------------------------------------------------------
# 1. Install Windows Updates
# -------------------------------------------------------------
$RebootRequired = Start-SystemUpdates


# -------------------------------------------------------------
# 2. Join the computer to the domain
# -------------------------------------------------------------
$DomainJoined = Add-ToDomain


# -------------------------------------------------------------
# 3. Final reboot
# -------------------------------------------------------------
if ($RebootRequired -or $DomainJoined) {

    Write-Host ""
    Write-Host "=============================================" `
        -ForegroundColor Yellow

    Write-Host "          FINAL RESTART" `
        -ForegroundColor Yellow

    Write-Host "=============================================" `
        -ForegroundColor Yellow

    Write-Host ""

    Write-Host "Updates will be finalized and the domain join" `
        -ForegroundColor White

    Write-Host "will be completed after the restart." `
        -ForegroundColor White

    Write-Host ""

    Start-Sleep -Seconds 5

    Restart-Computer -Force
}
else {

    Write-Host ""
    Write-Host "No restart is required." `
        -ForegroundColor Green
}
