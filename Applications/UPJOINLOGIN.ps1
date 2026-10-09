# ============================================================
# WINDOWS UPDATE + DOMAIN JOIN + ONE-TIME AUTOLOGON
# ============================================================

# ============================================================
# SETTINGS
# ============================================================

# Domain account used for joining the computer
$DomainUsername = "Techteam"

# Ask for the password securely
$DomainPassword = Read-Host `
    -Prompt "Enter the domain password for $DomainUsername" `
    -AsSecureString


# ============================================================
# REQUIRE ADMINISTRATOR
# ============================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {

    Write-Host "This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    Read-Host "Press ENTER to exit"
    exit 1
}


# ============================================================
# FUNCTION: START SYSTEM UPDATES
# ============================================================

function Start-SystemUpdates {

    $ModuleName = "PSWindowsUpdate"

    try {

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "          WINDOWS UPDATE PROCESS" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1/4] Checking NuGet provider..." -ForegroundColor Yellow

        Install-PackageProvider `
            -Name NuGet `
            -MinimumVersion 2.8.5.201 `
            -Force `
            -Confirm:$false `
            -ErrorAction SilentlyContinue |
            Out-Null


        Write-Host "[2/4] Checking PowerShell Gallery..." -ForegroundColor Yellow

        if (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue) {

            Set-PSRepository `
                -Name "PSGallery" `
                -InstallationPolicy Trusted `
                -ErrorAction SilentlyContinue
        }


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


        Write-Host "[4/4] Checking Microsoft Update..." -ForegroundColor Yellow
        Write-Host ""

        $Updates = @(
            Get-WindowsUpdate `
                -MicrosoftUpdate `
                -ErrorAction Stop
        )


        if ($Updates.Count -eq 0) {

            Write-Host ""
            Write-Host "No updates are currently available." -ForegroundColor Green
            Write-Host ""

            return $false
        }


        # ----------------------------------------------------
        # DISPLAY QUEUED UPDATES
        # ----------------------------------------------------

        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "            UPDATES QUEUED" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""

        $Number = 1

        foreach ($Update in $Updates) {

            Write-Host "[$Number] $($Update.Title)" -ForegroundColor White

            if ($Update.KB) {

                $KBText = @($Update.KB) -join ", "

                Write-Host `
                    "     KB: $KBText" `
                    -ForegroundColor DarkGray
            }


            # Safely handle update sizes
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

                        $TotalSize = (
                            $Sizes |
                            Measure-Object -Sum
                        ).Sum


                        if ($TotalSize -gt 0) {

                            $SizeMB = [math]::Round(
                                ($TotalSize / 1MB),
                                1
                            )

                            Write-Host `
                                "     Size: $SizeMB MB" `
                                -ForegroundColor DarkGray
                        }
                    }
                }
                catch {
                    # Ignore invalid size information
                }
            }


            if ($Update.Driver -eq $true) {

                Write-Host `
                    "     Type: DRIVER" `
                    -ForegroundColor Yellow
            }

            Write-Host ""

            $Number++
        }


        Write-Host `
            "Total updates queued: $($Updates.Count)" `
            -ForegroundColor Green

        Write-Host ""


        # ----------------------------------------------------
        # INSTALL UPDATES
        # ----------------------------------------------------

        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "          INSTALLING UPDATES" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
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


        # ----------------------------------------------------
        # CHECK FOR REBOOT
        # ----------------------------------------------------

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
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host "          UPDATE PROCESS COMPLETE" -ForegroundColor Green
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host ""


        if ($RebootRequired) {

            Write-Host `
                "A restart is required to finalize updates." `
                -ForegroundColor Yellow
        }
        else {

            Write-Host `
                "No restart is currently required." `
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
        Write-Host "Windows Update encountered an error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""

        return $false
    }
}


# ============================================================
# FUNCTION: DISCOVER DOMAIN AND JOIN
# ============================================================

function Add-ToDomain {

    try {

        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "             DOMAIN DISCOVERY" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""


        # ----------------------------------------------------
        # FIND DNS SERVERS
        # ----------------------------------------------------

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

            throw "No DNS servers were found."
        }


        Write-Host "DNS servers found:" -ForegroundColor Yellow

        foreach ($Dns in $DnsServers) {

            Write-Host "  $Dns" -ForegroundColor Gray
        }


        # ----------------------------------------------------
        # FIND CONNECTION-SPECIFIC DNS SUFFIXES
        # ----------------------------------------------------

        $DnsSuffixes = @(
            Get-DnsClient |
            Where-Object {
                $_.ConnectionSpecificSuffix
            } |
            Select-Object -ExpandProperty ConnectionSpecificSuffix |
            Sort-Object -Unique
        )


        $FoundDomains = @()


        # ----------------------------------------------------
        # QUERY AD LDAP SRV RECORDS
        # ----------------------------------------------------

        foreach ($Suffix in $DnsSuffixes) {

            foreach ($Dns in $DnsServers) {

                Write-Host ""
                Write-Host `
                    "Checking $Suffix using DNS server $Dns..." `
                    -ForegroundColor DarkGray


                try {

                    $SrvRecords = Resolve-DnsName `
                        "_ldap._tcp.dc._msdcs.$Suffix" `
                        -Type SRV `
                        -Server $Dns `
                        -ErrorAction Stop


                    if ($SrvRecords) {

                        if ($FoundDomains -notcontains $Suffix) {

                            $FoundDomains += $Suffix
                        }

                        Write-Host `
                            "Active Directory domain found: $Suffix" `
                            -ForegroundColor Green

                        break
                    }
                }
                catch {
                    # Try next DNS server
                }
            }
        }


        # ----------------------------------------------------
        # FALLBACK: REVERSE DNS
        # ----------------------------------------------------

        if ($FoundDomains.Count -eq 0) {

            Write-Host ""
            Write-Host `
                "DNS suffix discovery did not find the domain." `
                -ForegroundColor Yellow

            Write-Host `
                "Attempting reverse DNS discovery..." `
                -ForegroundColor Yellow


            foreach ($Dns in $DnsServers) {

                try {

                    $Reverse = Resolve-DnsName `
                        -Name $Dns `
                        -Type PTR `
                        -ErrorAction Stop


                    foreach ($PTR in $Reverse) {

                        if ($PTR.NameHost) {

                            $HostName = $PTR.NameHost.TrimEnd(".")

                            $Parts = $HostName.Split(".")

                            if ($Parts.Count -ge 2) {

                                $PossibleDomain = (
                                    $Parts[1..($Parts.Count - 1)] `
                                    -join "."
                                )


                                try {

                                    $Test = Resolve-DnsName `
                                        "_ldap._tcp.dc._msdcs.$PossibleDomain" `
                                        -Type SRV `
                                        -Server $Dns `
                                        -ErrorAction Stop


                                    if ($Test) {

                                        if ($FoundDomains -notcontains $PossibleDomain) {

                                            $FoundDomains += $PossibleDomain
                                        }
                                    }
                                }
                                catch {
                                    # Continue searching
                                }
                            }
                        }
                    }
                }
                catch {
                    # Continue searching
                }
            }
        }


        # ----------------------------------------------------
        # MAKE SURE DOMAIN WAS FOUND
        # ----------------------------------------------------

        if ($FoundDomains.Count -eq 0) {

            throw `
                "Unable to automatically discover an Active Directory domain."
        }


        # ----------------------------------------------------
        # SELECT DOMAIN
        # ----------------------------------------------------

        if ($FoundDomains.Count -eq 1) {

            $Domain = $FoundDomains[0]
        }
        else {

            Write-Host ""
            Write-Host "Multiple domains were discovered:" -ForegroundColor Yellow

            for ($i = 0; $i -lt $FoundDomains.Count; $i++) {

                Write-Host `
                    "[$($i + 1)] $($FoundDomains[$i])" `
                    -ForegroundColor White
            }


            do {

                $Selection = Read-Host "Select the domain number"

                $ValidSelection = (
                    [int]::TryParse(
                        $Selection,
                        [ref]$null
                    )
                )

            } until ($ValidSelection)


            $Domain = $FoundDomains[
                ([int]$Selection - 1)
            ]
        }


        Write-Host ""
        Write-Host `
            "Domain selected: $Domain" `
            -ForegroundColor Green


        # ----------------------------------------------------
        # CREATE CREDENTIAL
        # ----------------------------------------------------

        $Credential = New-Object `
            System.Management.Automation.PSCredential(
                "$Domain\$DomainUsername",
                $DomainPassword
            )


        # ----------------------------------------------------
        # JOIN COMPUTER
        # ----------------------------------------------------

        Write-Host ""
        Write-Host `
            "Joining computer to $Domain..." `
            -ForegroundColor Cyan


        Add-Computer `
            -DomainName $Domain `
            -Credential $Credential `
            -Force `
            -ErrorAction Stop


        Write-Host ""
        Write-Host `
            "Computer successfully joined to $Domain." `
            -ForegroundColor Green


        return @{
            Success = $true
            Domain  = $Domain
        }
    }
    catch {

        Write-Host ""
        Write-Host `
            "Domain join failed:" `
            -ForegroundColor Red

        Write-Host `
            $_.Exception.Message `
            -ForegroundColor Red

        return @{
            Success = $false
            Domain  = $null
        }
    }
}


# ============================================================
# FUNCTION: CONFIGURE ONE-TIME AUTOLOGON
# ============================================================

function Set-OneTimeAutoLogon {

    param (
        [Parameter(Mandatory)]
        [string]$Domain,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password
    )


    try {

        $AutoLogonPath =
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"


        # ----------------------------------------------------
        # FIND AUTOLOGON.EXE
        # ----------------------------------------------------

        $AutoLogonExe = Join-Path `
            $PSScriptRoot `
            "Autologon64.exe"


        if (-not (Test-Path $AutoLogonExe)) {

            throw @"
Autologon64.exe was not found.

Place Microsoft's Sysinternals Autologon64.exe in:

$PSScriptRoot
"@
        }


        # ----------------------------------------------------
        # CONVERT SECURE STRING ONLY WHEN NEEDED
        # ----------------------------------------------------

        $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $Password
        )


        try {

            $PlainPassword =
                [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                    $BSTR
                )
        }
        finally {

            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }


        # ----------------------------------------------------
        # ACCEPT SYSCINTERNALS EULA
        # ----------------------------------------------------

        Write-Host ""
        Write-Host `
            "Configuring one-time automatic login..." `
            -ForegroundColor Cyan


        # Autologon stores the password as an LSA secret rather
        # than using the plaintext DefaultPassword registry value.
        #
        # The password exists in plaintext only while being
        # passed to Autologon.exe.

        & $AutoLogonExe `
            "/accepteula" `
            $Username `
            $Domain `
            $PlainPassword


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Autologon.exe returned exit code $LASTEXITCODE."
        }


        # ----------------------------------------------------
        # REMOVE ANY PLAINTEXT PASSWORD VALUE
        # ----------------------------------------------------

        Remove-ItemProperty `
            -Path $AutoLogonPath `
            -Name "DefaultPassword" `
            -ErrorAction SilentlyContinue


        # ----------------------------------------------------
        # CREATE ONE-TIME CLEANUP TASK
        # ----------------------------------------------------

$CleanupScript = @'
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class LsaSecretManager
{
    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_UNICODE_STRING
    {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_OBJECT_ATTRIBUTES
    {
        public uint Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern uint LsaOpenPolicy(
        IntPtr SystemName,
        ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
        uint DesiredAccess,
        out IntPtr PolicyHandle
    );

    [DllImport("advapi32.dll")]
    public static extern uint LsaStorePrivateData(
        IntPtr PolicyHandle,
        ref LSA_UNICODE_STRING KeyName,
        IntPtr PrivateData
    );

    [DllImport("advapi32.dll")]
    public static extern uint LsaClose(
        IntPtr PolicyHandle
    );

    [DllImport("advapi32.dll")]
    public static extern uint LsaNtStatusToWinError(
        uint Status
    );

    public static string RemoveSecret(string SecretName)
    {
        IntPtr policyHandle = IntPtr.Zero;

        try
        {
            LSA_OBJECT_ATTRIBUTES attributes =
                new LSA_OBJECT_ATTRIBUTES();

            attributes.Length =
                (uint)Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));

            LSA_UNICODE_STRING key =
                new LSA_UNICODE_STRING();

            key.Length =
                (ushort)(SecretName.Length * 2);

            key.MaximumLength =
                (ushort)(key.Length + 2);

            key.Buffer =
                Marshal.StringToHGlobalUni(SecretName);

            uint status = LsaOpenPolicy(
                IntPtr.Zero,
                ref attributes,
                0x00000020,
                out policyHandle
            );

            if (status != 0)
            {
                return "LsaOpenPolicy failed: " +
                    LsaNtStatusToWinError(status);
            }

            // NULL PrivateData tells LSA to DELETE the secret.
            status = LsaStorePrivateData(
                policyHandle,
                ref key,
                IntPtr.Zero
            );

            Marshal.FreeHGlobal(key.Buffer);

            if (status != 0)
            {
                return "LsaStorePrivateData failed: " +
                    LsaNtStatusToWinError(status);
            }

            return "LSA secret deleted successfully.";
        }
        finally
        {
            if (policyHandle != IntPtr.Zero)
            {
                LsaClose(policyHandle);
            }
        }
    }
}

"@
    
$WinlogonPath =
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"


# ============================================================
# DELETE AUTOLOGON LSA SECRET
# ============================================================

$result =
    [LsaSecretManager]::RemoveSecret("DefaultPassword")


# ============================================================
# DISABLE AUTOLOGON
# ============================================================

Set-ItemProperty `
    -Path $WinlogonPath `
    -Name "AutoAdminLogon" `
    -Value "0" `
    -Force `
    -ErrorAction SilentlyContinue


# ============================================================
# REMOVE WINLOGON AUTLOGON SETTINGS
# ============================================================

Remove-ItemProperty `
    -Path $WinlogonPath `
    -Name "DefaultUserName" `
    -ErrorAction SilentlyContinue

Remove-ItemProperty `
    -Path $WinlogonPath `
    -Name "DefaultDomainName" `
    -ErrorAction SilentlyContinue

Remove-ItemProperty `
    -Path $WinlogonPath `
    -Name "DefaultPassword" `
    -ErrorAction SilentlyContinue

Remove-ItemProperty `
    -Path $WinlogonPath `
    -Name "AutoLogonSID" `
    -ErrorAction SilentlyContinue


# ============================================================
# DELETE CLEANUP SCRIPT
# ============================================================

$CleanupPath =
    Join-Path $env:ProgramData `
    "OneTimeDomainAutoLogonCleanup.ps1"


# Delete the scheduled task first
Unregister-ScheduledTask `
    -TaskName "OneTimeDomainAutoLogonCleanup" `
    -Confirm:$false `
    -ErrorAction SilentlyContinue


# Delete this script
Remove-Item `
    $CleanupPath `
    -Force `
    -ErrorAction SilentlyContinue
'@

# ============================================================
# MAIN SCRIPT
# ============================================================

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       COMPUTER SETUP / MAINTENANCE" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Domain account:" -ForegroundColor Yellow
Write-Host "    $DomainUsername" -ForegroundColor White
Write-Host ""


# ------------------------------------------------------------
# 1. INSTALL WINDOWS UPDATES
# ------------------------------------------------------------

$RebootRequired = Start-SystemUpdates


# ------------------------------------------------------------
# 2. DISCOVER DOMAIN AND JOIN COMPUTER
# ------------------------------------------------------------

$DomainResult = Add-ToDomain


if (-not $DomainResult.Success) {

    Write-Host ""
    Write-Host `
        "The computer was not joined to the domain." `
        -ForegroundColor Red

    Write-Host `
        "Automatic login will NOT be configured." `
        -ForegroundColor Red

    exit 1
}


$Domain = $DomainResult.Domain


# ------------------------------------------------------------
# 3. CONFIGURE ONE-TIME AUTOLOGIN
# ------------------------------------------------------------

$AutoLogonConfigured = Set-OneTimeAutoLogon `
    -Domain $Domain `
    -Username $DomainUsername `
    -Password $DomainPassword


if (-not $AutoLogonConfigured) {

    Write-Host ""
    Write-Host `
        "Automatic login could not be configured." `
        -ForegroundColor Red

    Write-Host `
        "The computer will NOT automatically reboot." `
        -ForegroundColor Yellow

    exit 1
}


# ------------------------------------------------------------
# 4. FINAL REBOOT
# ------------------------------------------------------------

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "           SETUP COMPLETE" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Computer joined to:" -ForegroundColor Cyan
Write-Host "    $Domain" -ForegroundColor White

Write-Host ""
Write-Host "Automatic login configured for:" -ForegroundColor Cyan
Write-Host "    $Domain\$DomainUsername" -ForegroundColor White

Write-Host ""
Write-Host "The computer will restart in 10 seconds." -ForegroundColor Yellow
Write-Host ""
Write-Host "After restart:" -ForegroundColor Cyan
Write-Host "  1. Windows will automatically log in." -ForegroundColor White
Write-Host "  2. The cleanup task will disable AutoLogon." -ForegroundColor White
Write-Host "  3. The cleanup task will remove itself." -ForegroundColor White
Write-Host "  4. Future restarts will require normal login." -ForegroundColor White
Write-Host ""

Start-Sleep -Seconds 10

Restart-Computer -Force
