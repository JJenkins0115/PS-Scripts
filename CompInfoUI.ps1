# ============================================================
# COMPUTER INFORMATION GUI
# ============================================================
# Standalone PowerShell GUI
# Does NOT interact with AppCleanup.ps1
#
# Requires:
#   Windows PowerShell 5.1+
#   Windows
#
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# COLORS
# ============================================================

$ColorBackground = [System.Drawing.Color]::FromArgb(245,247,250)
$ColorHeader     = [System.Drawing.Color]::FromArgb(30,41,59)
$ColorBlue       = [System.Drawing.Color]::FromArgb(37,99,235)
$ColorText       = [System.Drawing.Color]::FromArgb(30,41,59)
$ColorSubText    = [System.Drawing.Color]::FromArgb(100,116,139)
$ColorWhite      = [System.Drawing.Color]::White
$ColorGreen      = [System.Drawing.Color]::FromArgb(22,163,74)
$ColorRed        = [System.Drawing.Color]::FromArgb(220,38,38)

# ============================================================
# GET COMPUTER INFORMATION
# ============================================================

function Get-ComputerInformation {

    $Computer = Get-CimInstance Win32_ComputerSystem
    $BIOS     = Get-CimInstance Win32_BIOS
    $OS       = Get-CimInstance Win32_OperatingSystem
    $CPU      = Get-CimInstance Win32_Processor | Select-Object -First 1

    $Registry = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    # --------------------------------------------------------
    # DOMAIN / OU
    # --------------------------------------------------------

    $Domain = $null
    $OU = "Not Domain Joined"
    $DistinguishedName = $null

    if ($Computer.PartOfDomain) {

        $Domain = $Computer.Domain

        try {

            $Searcher = New-Object `
                System.DirectoryServices.DirectorySearcher

            $Searcher.Filter = `
                "(&(objectCategory=computer)(sAMAccountName=$($Computer.Name)`$))"

            $Searcher.PropertiesToLoad.Add(
                "distinguishedname"
            ) | Out-Null

            $Result = $Searcher.FindOne()

            if ($Result) {

                $DistinguishedName =
                    $Result.Properties["distinguishedname"][0]

                if ($DistinguishedName) {

                    # Remove computer CN
                    $OU = $DistinguishedName `
                        -replace '^CN=[^,]+,', ''

                    # Convert DC=company,DC=local
                    # portions to a readable domain name

                    $OU = $OU `
                        -replace '(?i),?DC=[^,]+',''

                    $OU = $OU.Trim(',')

                    if ([string]::IsNullOrWhiteSpace($OU)) {

                        $OU = "Domain Root"
                    }
                }
            }

        }
        catch {

            $OU = "Unable to determine OU"
        }
    }
    else {

        $Domain = $Computer.Workgroup
    }

    # --------------------------------------------------------
    # MEMORY
    # --------------------------------------------------------

    $RAMGB = [math]::Round(
        $Computer.TotalPhysicalMemory / 1GB,
        2
    )

    # --------------------------------------------------------
    # WINDOWS
    # --------------------------------------------------------

    $DisplayVersion = $Registry.DisplayVersion

    if ([string]::IsNullOrWhiteSpace($DisplayVersion)) {

        $DisplayVersion = $Registry.ReleaseId
    }

    # --------------------------------------------------------
    # UPTIME
    # --------------------------------------------------------

    $Uptime = $null

    if ($OS.LastBootUpTime) {

        $BootTime = $OS.LastBootUpTime

        $UptimeSpan = (Get-Date) - $BootTime

        $Uptime = "{0} days, {1} hours, {2} minutes" -f `
            $UptimeSpan.Days,
            $UptimeSpan.Hours,
            $UptimeSpan.Minutes
    }

    # --------------------------------------------------------
    # BIOS DATE
    # --------------------------------------------------------

    $BIOSDate = ""

    if ($BIOS.ReleaseDate) {

        $BIOSDate = $BIOS.ReleaseDate.ToString("yyyy-MM-dd")
    }

    # --------------------------------------------------------
    # RETURN OBJECT
    # --------------------------------------------------------

    return [PSCustomObject]@{

        ComputerName = $Computer.Name

        Manufacturer = $Computer.Manufacturer

        Model = $Computer.Model

        SerialNumber = $BIOS.SerialNumber

        Domain = $Domain

        OU = $OU

        DistinguishedName = $DistinguishedName

        IsDomainJoined = $Computer.PartOfDomain

        Windows = $OS.Caption

        DisplayVersion = $DisplayVersion

        Build = $OS.BuildNumber

        Architecture = $OS.OSArchitecture

        InstallDate = $OS.InstallDate

        LastBoot = $OS.LastBootUpTime

        Uptime = $Uptime

        CPU = $CPU.Name

        CPUCores = $CPU.NumberOfCores

        CPUThreads = $CPU.NumberOfLogicalProcessors

        CPUSpeed = "$($CPU.MaxClockSpeed) MHz"

        RAM = "$RAMGB GB"

        BIOSManufacturer = $BIOS.Manufacturer

        BIOSVersion = $BIOS.SMBIOSBIOSVersion

        BIOSDate = $BIOSDate

        User = "$env:USERDOMAIN\$env:USERNAME"
    }
}

# ============================================================
# GET DOMAIN CONTROLLER
# ============================================================

function Get-DomainControllerInfo {

    $Computer = Get-CimInstance Win32_ComputerSystem

    if (!$Computer.PartOfDomain) {

        return $null
    }

    try {

        $Result = nltest /dsgetdc:$($Computer.Domain) 2>&1

        if ($LASTEXITCODE -eq 0) {

            return ($Result -join "`r`n")
        }
    }
    catch {
    }

    return "Unable to determine domain controller."
}

# ============================================================
# GET DNS INFORMATION
# ============================================================

function Get-DNSInfo {

    try {

        $DNS = Get-DnsClientServerAddress `
            -AddressFamily IPv4

        $Output = @()

        foreach ($Adapter in $DNS) {

            if ($Adapter.ServerAddresses.Count -gt 0) {

                $Output += "[$($Adapter.InterfaceAlias)]"

                foreach ($Server in $Adapter.ServerAddresses) {

                    $Output += "  $Server"
                }

                $Output += ""
            }
        }

        return ($Output -join "`r`n")
    }
    catch {

        return "Unable to retrieve DNS information."
    }
}

# ============================================================
# GET NETWORK INFORMATION
# ============================================================

function Get-NetworkInfo {

    try {

        $Adapters = Get-NetAdapter -Physical

        $Output = @()

        foreach ($Adapter in $Adapters) {

            $Output += "================================================"
            $Output += "Adapter: $($Adapter.Name)"
            $Output += "================================================"

            $Output += "Description : $($Adapter.InterfaceDescription)"
            $Output += "Status      : $($Adapter.Status)"
            $Output += "MAC Address : $($Adapter.MacAddress)"

            $IPs = Get-NetIPAddress `
                -InterfaceIndex $Adapter.ifIndex `
                -AddressFamily IPv4

            foreach ($IP in $IPs) {

                if (
                    $IP.IPAddress -notlike "127.*" -and
                    $IP.IPAddress -notlike "169.254.*"
                ) {

                    $Output += "IPv4        : $($IP.IPAddress)"
                    $Output += "Prefix      : $($IP.PrefixLength)"
                }
            }

            $Output += ""
        }

        return ($Output -join "`r`n")

    }
    catch {

        return "Unable to retrieve network information."
    }
}

# ============================================================
# GET DISK INFORMATION
# ============================================================

function Get-DiskInfo {

    try {

        $Disks = Get-CimInstance Win32_LogicalDisk `
            -Filter "DriveType=3"

        $Output = @()

        foreach ($Disk in $Disks) {

            $Size = [math]::Round(
                $Disk.Size / 1GB,
                2
            )

            $Free = [math]::Round(
                $Disk.FreeSpace / 1GB,
                2
            )

            $Used = [math]::Round(
                $Size - $Free,
                2
            )

            $FreePercent = 0

            if ($Size -gt 0) {

                $FreePercent = [math]::Round(
                    ($Free / $Size) * 100,
                    1
                )
            }

            $Output += "Drive: $($Disk.DeviceID)"
            $Output += "Volume: $($Disk.VolumeName)"
            $Output += "Total : $Size GB"
            $Output += "Used  : $Used GB"
            $Output += "Free  : $Free GB"
            $Output += "Free% : $FreePercent%"
            $Output += ""

        }

        return ($Output -join "`r`n")
    }
    catch {

        return "Unable to retrieve disk information."
    }
}

# ============================================================
# SECURE CHANNEL
# ============================================================

function Get-SecureChannelInfo {

    $Computer = Get-CimInstance Win32_ComputerSystem

    if (!$Computer.PartOfDomain) {

        return "Not applicable - computer is not domain joined."
    }

    try {

        if (Test-ComputerSecureChannel) {

            return "HEALTHY"
        }
        else {

            return "BROKEN"
        }

    }
    catch {

        return "Unable to test secure channel."
    }
}

# ============================================================
# GROUP POLICY
# ============================================================

function Get-GroupPolicyInfo {

    try {

        return (
            gpresult /r /scope computer 2>&1 |
            Out-String
        )

    }
    catch {

        return "Unable to retrieve Group Policy information."
    }
}

# ============================================================
# CREATE LABEL
# ============================================================

function New-InfoLabel {

    param(
        [string]$Text
    )

    $Label = New-Object System.Windows.Forms.Label

    $Label.Text = $Text

    $Label.AutoSize = $true

    $Label.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI",
            10
        )

    $Label.ForeColor = $ColorText

    return $Label
}

# ============================================================
# CREATE DROPDOWN SECTION
# ============================================================

function Add-Section {

    param(

        [System.Windows.Forms.FlowLayoutPanel]$Parent,

        [string]$Title,

        [string]$Content

    )

    $Panel = New-Object System.Windows.Forms.Panel

    $Panel.Width = 760

    $Panel.Height = 48

    $Panel.BackColor = $ColorWhite

    $Button = New-Object System.Windows.Forms.Button

    $Button.Text = "▶  $Title"

    $Button.Width = 740

    $Button.Height = 42

    $Button.Location = New-Object `
        System.Drawing.Point(10,3)

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI Semibold",
            10
        )

    $Button.TextAlign = "MiddleLeft"

    $TextBox = New-Object `
        System.Windows.Forms.RichTextBox

    $TextBox.Text = $Content

    $TextBox.ReadOnly = $true

    $TextBox.BackColor = $ColorWhite

    $TextBox.ForeColor = $ColorText

    $TextBox.BorderStyle = "None"

    $TextBox.Font = New-Object `
        System.Drawing.Font(
            "Consolas",
            9
        )

    $TextBox.Location = New-Object `
        System.Drawing.Point(20,48)

    $TextBox.Width = 720

    $TextBox.Height = 10

    $TextBox.Visible = $false

    $TextBox.Anchor = `
        [System.Windows.Forms.AnchorStyles]::Top `
        -bor [System.Windows.Forms.AnchorStyles]::Left `
        -bor [System.Windows.Forms.AnchorStyles]::Right

    $Panel.Controls.Add($Button)

    $Panel.Controls.Add($TextBox)

    $Button.Add_Click({

        if ($TextBox.Visible) {

            $TextBox.Visible = $false

            $Panel.Height = 48

            $Button.Text = "▶  $Title"

        }
        else {

            $TextBox.Visible = $true

            $LineCount = ($Content -split "`r?`n").Count

            $Height = [Math]::Min(
                400,
                [Math]::Max(
                    80,
                    ($LineCount * 18) + 20
                )
            )

            $TextBox.Height = $Height

            $Panel.Height = $Height + 55

            $Button.Text = "▼  $Title"
        }

        $Parent.PerformLayout()

    })

    $Parent.Controls.Add($Panel)
}

# ============================================================
# MAIN WINDOW
# ============================================================

$Form = New-Object System.Windows.Forms.Form

$Form.Text = "Computer Information"

$Form.Size = New-Object `
    System.Drawing.Size(
        850,
        850
    )

$Form.StartPosition = "CenterScreen"

$Form.BackColor = $ColorBackground

$Form.MinimumSize = New-Object `
    System.Drawing.Size(
        700,
        700
    )

# ============================================================
# HEADER
# ============================================================

$Header = New-Object System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 155

$Header.BackColor = $ColorHeader

$Form.Controls.Add($Header)

# ------------------------------------------------------------
# Device Name
# ------------------------------------------------------------

$DeviceLabel = New-Object System.Windows.Forms.Label

$DeviceLabel.Text = "DEVICE"

$DeviceLabel.Location = New-Object `
    System.Drawing.Point(
        30,
        18
    )

$DeviceLabel.AutoSize = $true

$DeviceLabel.ForeColor = `
    [System.Drawing.Color]::FromArgb(
        148,
        163,
        184
    )

$DeviceLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        10
    )

$Header.Controls.Add($DeviceLabel)

$DeviceNameLabel = New-Object `
    System.Windows.Forms.Label

$DeviceNameLabel.Location = New-Object `
    System.Drawing.Point(
        28,
        40
    )

$DeviceNameLabel.AutoSize = $true

$DeviceNameLabel.ForeColor = $ColorWhite

$DeviceNameLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI Semibold",
        24
    )

$Header.Controls.Add($DeviceNameLabel)

# ------------------------------------------------------------
# Domain
# ------------------------------------------------------------

$DomainLabel = New-Object System.Windows.Forms.Label

$DomainLabel.Text = "DOMAIN"

$DomainLabel.Location = New-Object `
    System.Drawing.Point(
        400,
        18
    )

$DomainLabel.AutoSize = $true

$DomainLabel.ForeColor = `
    [System.Drawing.Color]::FromArgb(
        148,
        163,
        184
    )

$DomainLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        10
    )

$Header.Controls.Add($DomainLabel)

$DomainValueLabel = New-Object `
    System.Windows.Forms.Label

$DomainValueLabel.Location = New-Object `
    System.Drawing.Point(
        398,
        40
    )

$DomainValueLabel.AutoSize = $true

$DomainValueLabel.ForeColor = $ColorWhite

$DomainValueLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI Semibold",
        15
    )

$Header.Controls.Add($DomainValueLabel)

# ------------------------------------------------------------
# OU
# ------------------------------------------------------------

$OULabel = New-Object System.Windows.Forms.Label

$OULabel.Text = "ORGANIZATIONAL UNIT"

$OULabel.Location = New-Object `
    System.Drawing.Point(
        30,
        95
    )

$OULabel.AutoSize = $true

$OULabel.ForeColor = `
    [System.Drawing.Color]::FromArgb(
        148,
        163,
        184
    )

$OULabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        9
    )

$Header.Controls.Add($OULabel)

$OUValueLabel = New-Object `
    System.Windows.Forms.Label

$OUValueLabel.Location = New-Object `
    System.Drawing.Point(
        30,
        115
    )

$OUValueLabel.AutoSize = $true

$OUValueLabel.MaximumSize = New-Object `
    System.Drawing.Size(
        760,
        0
    )

$OUValueLabel.ForeColor = $ColorWhite

$OUValueLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        10
    )

$Header.Controls.Add($OUValueLabel)

# ============================================================
# REFRESH BUTTON
# ============================================================

$RefreshButton = New-Object `
    System.Windows.Forms.Button

$RefreshButton.Text = "⟳  Refresh"

$RefreshButton.Width = 110

$RefreshButton.Height = 35

$RefreshButton.Location = New-Object `
    System.Drawing.Point(
        700,
        20
    )

$RefreshButton.FlatStyle = "Flat"

$RefreshButton.FlatAppearance.BorderSize = 0

$RefreshButton.BackColor = $ColorBlue

$RefreshButton.ForeColor = $ColorWhite

$RefreshButton.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI Semibold",
        9
    )

$Header.Controls.Add($RefreshButton)

# ============================================================
# SCROLL AREA
# ============================================================

$ScrollPanel = New-Object `
    System.Windows.Forms.Panel

$ScrollPanel.Dock = "Fill"

$ScrollPanel.AutoScroll = $true

$ScrollPanel.Padding = New-Object `
    System.Windows.Forms.Padding(
        25,
        20,
        25,
        20
    )

$ScrollPanel.BackColor = $ColorBackground

$Form.Controls.Add($ScrollPanel)

$ScrollPanel.BringToFront()

# ============================================================
# FLOW LAYOUT
# ============================================================

$Sections = New-Object `
    System.Windows.Forms.FlowLayoutPanel

$Sections.FlowDirection = "TopDown"

$Sections.WrapContents = $false

$Sections.AutoSize = $true

$Sections.Width = 780

$Sections.BackColor = $ColorBackground

$ScrollPanel.Controls.Add($Sections)

# ============================================================
# LOAD INFORMATION
# ============================================================

function Load-Information {

    $RefreshButton.Enabled = $false

    $RefreshButton.Text = "Loading..."

    try {

        $Info = Get-ComputerInformation

        # ----------------------------------------------------
        # Header
        # ----------------------------------------------------

        $DeviceNameLabel.Text =
            $Info.ComputerName

        $DomainValueLabel.Text =
            $Info.Domain

        $OUValueLabel.Text =
            $Info.OU

        # ----------------------------------------------------
        # Clear Existing Sections
        # ----------------------------------------------------

        $Sections.Controls.Clear()

        # ----------------------------------------------------
        # Computer
        # ----------------------------------------------------

        $ComputerInfo = @"

Computer Name : $($Info.ComputerName)
Manufacturer  : $($Info.Manufacturer)
Model         : $($Info.Model)
Serial Number : $($Info.SerialNumber)
User          : $($Info.User)

"@

        Add-Section `
            -Parent $Sections `
            -Title "Computer" `
            -Content $ComputerInfo

        # ----------------------------------------------------
        # Windows
        # ----------------------------------------------------

        $WindowsInfo = @"

Windows       : $($Info.Windows)
Version       : $($Info.DisplayVersion)
Build         : $($Info.Build)
Architecture  : $($Info.Architecture)
Install Date  : $($Info.InstallDate)
Last Boot     : $($Info.LastBoot)
Uptime        : $($Info.Uptime)

"@

        Add-Section `
            -Parent $Sections `
            -Title "Windows" `
            -Content $WindowsInfo

        # ----------------------------------------------------
        # Hardware
        # ----------------------------------------------------

        $HardwareInfo = @"

CPU           : $($Info.CPU)
Cores         : $($Info.CPUCores)
Threads       : $($Info.CPUThreads)
CPU Speed     : $($Info.CPUSpeed)
Memory        : $($Info.RAM)

"@

        Add-Section `
            -Parent $Sections `
            -Title "Hardware" `
            -Content $HardwareInfo

        # ----------------------------------------------------
        # BIOS
        # ----------------------------------------------------

        $BIOSInfo = @"

Manufacturer  : $($Info.BIOSManufacturer)
Version       : $($Info.BIOSVersion)
Release Date  : $($Info.BIOSDate)
Serial Number : $($Info.SerialNumber)

"@

        Add-Section `
            -Parent $Sections `
            -Title "BIOS" `
            -Content $BIOSInfo

        # ----------------------------------------------------
        # Domain
        # ----------------------------------------------------

        $DomainInfo = @"

Domain Joined : $($Info.IsDomainJoined)
Domain        : $($Info.Domain)
OU            : $($Info.OU)

Distinguished Name:

$($Info.DistinguishedName)

"@

        Add-Section `
            -Parent $Sections `
            -Title "Active Directory / Domain" `
            -Content $DomainInfo

        # ----------------------------------------------------
        # Domain Controller
        # ----------------------------------------------------

        Add-Section `
            -Parent $Sections `
            -Title "Domain Controller" `
            -Content (Get-DomainControllerInfo)

        # ----------------------------------------------------
        # Secure Channel
        # ----------------------------------------------------

        $SecureChannel = Get-SecureChannelInfo

        Add-Section `
            -Parent $Sections `
            -Title "Domain Secure Channel" `
            -Content $SecureChannel

        # ----------------------------------------------------
        # Network
        # ----------------------------------------------------

        Add-Section `
            -Parent $Sections `
            -Title "Network Adapters" `
            -Content (Get-NetworkInfo)

        # ----------------------------------------------------
        # DNS
        # ----------------------------------------------------

        Add-Section `
            -Parent $Sections `
            -Title "DNS" `
            -Content (Get-DNSInfo)

        # ----------------------------------------------------
        # Storage
        # ----------------------------------------------------

        Add-Section `
            -Parent $Sections `
            -Title "Storage" `
            -Content (Get-DiskInfo)

        # ----------------------------------------------------
        # Group Policy
        # ----------------------------------------------------

        Add-Section `
            -Parent $Sections `
            -Title "Group Policy" `
            -Content (Get-GroupPolicyInfo)

    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load computer information.`r`n`r`n$($_.Exception.Message)",
            "Computer Information",
            "OK",
            "Error"
        )
    }

    $RefreshButton.Enabled = $true

    $RefreshButton.Text = "⟳  Refresh"
}

# ============================================================
# REFRESH EVENT
# ============================================================

$RefreshButton.Add_Click({

    Load-Information

})

# ============================================================
# FORM LOAD
# ============================================================

$Form.Add_Shown({

    Load-Information

})

# ============================================================
# RUN APPLICATION
# ============================================================

[void]$Form.ShowDialog()
