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

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "        ACTIVE DIRECTORY DISCOVERY" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    # ---------------------------------------------------------
    # Get DNS servers currently being used
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

        Write-Host "No DNS servers were found." -ForegroundColor Red
        Write-Host ""
        return
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

        Write-Host "Searching DNS server $Dns..." -ForegroundColor Cyan

        foreach ($Suffix in $DnsSuffixes) {

            Write-Host "  Checking $Suffix..." -ForegroundColor DarkGray

            try {

                $LDAPRecords = Resolve-DnsName `
                    "_ldap._tcp.dc._msdcs.$Suffix" `
                    -Type SRV `
                    -Server $Dns `
                    -ErrorAction Stop

                if ($LDAPRecords) {

                    Write-Host "  Active Directory found!" -ForegroundColor Green

                    if ($Suffix -notin $FoundDomains) {
                        $FoundDomains += $Suffix
                    }

                    foreach ($Record in $LDAPRecords) {

                        if ($Record.NameTarget) {

                            Write-Host "    Domain Controller: $($Record.NameTarget)" `
                                -ForegroundColor Gray
                        }
                    }
                }
            }
            catch {
                # No LDAP record for this suffix
            }
        }
    }

    # ---------------------------------------------------------
    # If no domain was found using the local suffix,
    # try using the DNS server's hostname.
    # ---------------------------------------------------------
    if ($FoundDomains.Count -eq 0) {

        Write-Host ""
        Write-Host "No domain found from local DNS suffixes." `
            -ForegroundColor Yellow

        Write-Host "Attempting reverse DNS discovery..." `
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

                        Write-Host "DNS server hostname: $Hostname" `
                            -ForegroundColor Gray

                        # Get everything after the first hostname component
                        $Parts = $Hostname.Split(".")

                        if ($Parts.Count -ge 2) {

                            $PossibleDomain = (
                                $Parts[1..($Parts.Count - 1)] -join "."
                            )

                            Write-Host "Testing possible domain: $PossibleDomain" `
                                -ForegroundColor Cyan

                            try {

                                $LDAPRecords = Resolve-DnsName `
                                    "_ldap._tcp.dc._msdcs.$PossibleDomain" `
                                    -Type SRV `
                                    -Server $Dns `
                                    -ErrorAction Stop

                                if ($LDAPRecords) {

                                    Write-Host "  Active Directory found!" `
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
    # No domains found
    # ---------------------------------------------------------
    if ($FoundDomains.Count -eq 0) {

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Red
        Write-Host "       NO ACTIVE DIRECTORY DOMAIN FOUND" -ForegroundColor Red
        Write-Host "=============================================" -ForegroundColor Red
        Write-Host ""

        Write-Host "DNS servers detected:" -ForegroundColor Yellow

        foreach ($Dns in $DnsServers) {
            Write-Host "  $Dns" -ForegroundColor Gray
        }

        Write-Host ""

        Write-Host "Unable to locate an Active Directory domain." `
            -ForegroundColor Red

        return
    }

    # ---------------------------------------------------------
    # Remove duplicates
    # ---------------------------------------------------------
    $FoundDomains = @(
        $FoundDomains |
        Sort-Object -Unique
    )

    # ---------------------------------------------------------
    # Display domains found
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "          DOMAINS FOUND" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""

    for ($i = 0; $i -lt $FoundDomains.Count; $i++) {

        Write-Host "[$($i + 1)] $($FoundDomains[$i])" `
            -ForegroundColor White
    }

    Write-Host ""

    # ---------------------------------------------------------
    # Select domain
    # ---------------------------------------------------------
    if ($FoundDomains.Count -eq 1) {

        $Domain = $FoundDomains[0]

        Write-Host "Domain automatically selected:" `
            -ForegroundColor Cyan

        Write-Host "  $Domain" -ForegroundColor Green
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

            Write-Host "Invalid selection." -ForegroundColor Red

        } while ($true)
    }

    # ---------------------------------------------------------
    # Username
    # ---------------------------------------------------------
    Write-Host ""
    $Username = Read-Host "Enter domain username [Techteam]"

    if ([string]::IsNullOrWhiteSpace($Username)) {
        $Username = "Techteam"
    }

    # ---------------------------------------------------------
    # Password
    # ---------------------------------------------------------
    $Password = Read-Host `
        -Prompt "Enter domain password for $Username" `
        -AsSecureString

    $Credential = New-Object System.Management.Automation.PSCredential(
        "$Domain\$Username",
        $Password
    )

    # ---------------------------------------------------------
    # Confirmation
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "          DOMAIN JOIN CONFIRMATION" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Domain:   $Domain" -ForegroundColor White
    Write-Host "Username: $Username" -ForegroundColor White
    Write-Host ""

    $Confirm = Read-Host `
        "Join this computer to $Domain and restart? (Y/N)"

    if ($Confirm -notmatch "^[Yy]$") {

        Write-Host ""
        Write-Host "Domain join cancelled." -ForegroundColor Yellow
        return
    }

    # ---------------------------------------------------------
    # Join domain
    # ---------------------------------------------------------
    Write-Host ""
    Write-Host "Joining $Domain..." -ForegroundColor Yellow
    Write-Host ""

    try {

        Add-Computer `
            -DomainName $Domain `
            -Credential $Credential `
            -Restart `
            -Force
    }
    catch {

        Write-Host ""
        Write-Host "Failed to join domain." -ForegroundColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ============================================================
# SCRIPT EXECUTION
# ============================================================

# 1. Run Windows Updates
Start-SystemUpdates

# 2. Add computer to domain and restart
Add-ToDomain
