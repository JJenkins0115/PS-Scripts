# ============================================================
# COMPUTER INFORMATION GUI
# ============================================================
# Windows PowerShell 5.1+
#
# Displays:
#   Computer information
#   Windows information
#   Hardware information
#   BIOS information
#   Active Directory / Domain information
#   Domain Controller
#   Secure Channel
#   Network adapters
#   DNS
#   Storage
#   Group Policy
#
# The PowerShell console is hidden while the GUI is running.
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# HIDE POWERSHELL CONSOLE
# ============================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(
        IntPtr hWnd,
        int nCmdShow
    );
}
"@

$ConsoleHandle = [ConsoleWindow]::GetConsoleWindow()

if ($ConsoleHandle -ne [IntPtr]::Zero) {
    [ConsoleWindow]::ShowWindow(
        $ConsoleHandle,
        0
    )
}

# ============================================================
# LOAD WINDOWS FORMS
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

[System.Windows.Forms.Application]::EnableVisualStyles()

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
$ColorBorder     = [System.Drawing.Color]::FromArgb(226,232,240)

# ============================================================
# GET COMPUTER INFORMATION
# ============================================================

function Get-ComputerInformation {

    $Computer = Get-CimInstance Win32_ComputerSystem
    $BIOS     = Get-CimInstance Win32_BIOS
    $OS       = Get-CimInstance Win32_OperatingSystem
    $CPU      = Get-CimInstance Win32_Processor |
        Select-Object -First 1

    $Registry = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    # --------------------------------------------------------
    # DOMAIN / OU
    # --------------------------------------------------------

    $Domain = "Not Domain Joined"
    $OU = "Not Domain Joined"
    $DistinguishedName = $null

    if ($Computer.PartOfDomain) {

        $Domain = $Computer.Domain

        try {

            $Searcher = New-Object `
                System.DirectoryServices.DirectorySearcher

            $Searcher.Filter =
                "(&(objectCategory=computer)(sAMAccountName=$($Computer.Name)`$))"

            [void]$Searcher.PropertiesToLoad.Add(
                "distinguishedname"
            )

            $Result = $Searcher.FindOne()

            if ($Result) {

                if (
                    $Result.Properties.Contains(
                        "distinguishedname"
                    )
                ) {

                    $DistinguishedName =
                        $Result.Properties["distinguishedname"][0]

                    if ($DistinguishedName) {

                        # Remove computer CN
                        $OU = $DistinguishedName `
                            -replace '^CN=[^,]+,', ''

                        # Remove DC components
                        $OU = $OU `
                            -replace '(?i),?DC=[^,]+',''

                        $OU = $OU.Trim(',')

                        if (
                            [string]::IsNullOrWhiteSpace($OU)
                        ) {

                            $OU = "Domain Root"
                        }
                    }
                }
            }
            else {

                $OU = "Unable to determine OU"
            }

        }
        catch {

            $OU = "Unable to determine OU"
        }
    }
    else {

        if ($Computer.Workgroup) {
            $Domain = $Computer.Workgroup
        }
    }

    # --------------------------------------------------------
    # MEMORY
    # --------------------------------------------------------

    $RAMGB = [math]::Round(
        $Computer.TotalPhysicalMemory / 1GB,
        2
    )

    # --------------------------------------------------------
    # WINDOWS VERSION
    # --------------------------------------------------------

    $DisplayVersion = $Registry.DisplayVersion

    if (
        [string]::IsNullOrWhiteSpace(
            $DisplayVersion
        )
    ) {

        $DisplayVersion = $Registry.ReleaseId
    }

    # --------------------------------------------------------
    # UPTIME
    # --------------------------------------------------------

    $Uptime = "Unknown"

    if ($OS.LastBootUpTime) {

        $BootTime = $OS.LastBootUpTime

        $UptimeSpan = (
            Get-Date
        ) - $BootTime

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

        try {
            $BIOSDate =
                $BIOS.ReleaseDate.ToString(
                    "yyyy-MM-dd"
                )
        }
        catch {
            $BIOSDate =
                $BIOS.ReleaseDate.ToString()
        }
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

        DistinguishedName =
            $DistinguishedName

        IsDomainJoined =
            $Computer.PartOfDomain

        Windows =
            $OS.Caption

        DisplayVersion =
            $DisplayVersion

        Build =
            $OS.BuildNumber

        Architecture =
            $OS.OSArchitecture

        InstallDate =
            $OS.InstallDate

        LastBoot =
            $OS.LastBootUpTime

        Uptime =
            $Uptime

        CPU =
            $CPU.Name

        CPUCores =
            $CPU.NumberOfCores

        CPUThreads =
            $CPU.NumberOfLogicalProcessors

        CPUSpeed =
            "$($CPU.MaxClockSpeed) MHz"

        RAM =
            "$RAMGB GB"

        BIOSManufacturer =
            $BIOS.Manufacturer

        BIOSVersion =
            $BIOS.SMBIOSBIOSVersion

        BIOSDate =
            $BIOSDate

        User =
            "$env:USERDOMAIN\$env:USERNAME"
    }
}

# ============================================================
# DOMAIN CONTROLLER
# ============================================================

function Get-DomainControllerInfo {

    $Computer =
        Get-CimInstance Win32_ComputerSystem

    if (!$Computer.PartOfDomain) {

        return "Not applicable - computer is not domain joined."
    }

    try {

        $Result =
            nltest /dsgetdc:$($Computer.Domain) 2>&1

        if ($LASTEXITCODE -eq 0) {

            return (
                $Result -join "`r`n"
            )
        }
    }
    catch {
    }

    return "Unable to determine domain controller."
}

# ============================================================
# DNS INFORMATION
# ============================================================

function Get-DNSInfo {

    try {

        $DNS =
            Get-DnsClientServerAddress `
                -AddressFamily IPv4

        $Output = @()

        foreach ($Adapter in $DNS) {

            if (
                $Adapter.ServerAddresses.Count -gt 0
            ) {

                $Output += "Interface: $($Adapter.InterfaceAlias)"

                foreach (
                    $Server in $Adapter.ServerAddresses
                ) {

                    $Output += "  DNS Server: $Server"
                }

                $Output += ""
            }
        }

        if ($Output.Count -eq 0) {

            return "No DNS servers found."
        }

        return (
            $Output -join "`r`n"
        )
    }
    catch {

        return "Unable to retrieve DNS information."
    }
}

# ============================================================
# NETWORK INFORMATION
# ============================================================

function Get-NetworkInfo {

    try {

        $Adapters =
            Get-NetAdapter -Physical

        $Output = @()

        foreach ($Adapter in $Adapters) {

            $Output += "================================================"
            $Output += "Adapter: $($Adapter.Name)"
            $Output += "================================================"

            $Output +=
                "Description : $($Adapter.InterfaceDescription)"

            $Output +=
                "Status      : $($Adapter.Status)"

            $Output +=
                "MAC Address : $($Adapter.MacAddress)"

            try {

                $IPs =
                    Get-NetIPAddress `
                        -InterfaceIndex $Adapter.ifIndex `
                        -AddressFamily IPv4

                foreach ($IP in $IPs) {

                    if (
                        $IP.IPAddress -notlike "127.*" -and
                        $IP.IPAddress -notlike "169.254.*"
                    ) {

                        $Output +=
                            "IPv4        : $($IP.IPAddress)"

                        $Output +=
                            "Prefix      : $($IP.PrefixLength)"
                    }
                }
            }
            catch {
            }

            $Output += ""
        }

        if ($Output.Count -eq 0) {

            return "No physical network adapters found."
        }

        return (
            $Output -join "`r`n"
        )
    }
    catch {

        return "Unable to retrieve network information."
    }
}

# ============================================================
# DISK INFORMATION
# ============================================================

function Get-DiskInfo {

    try {

        $Disks =
            Get-CimInstance Win32_LogicalDisk `
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

                $FreePercent =
                    [math]::Round(
                        ($Free / $Size) * 100,
                        1
                    )
            }

            $Output += "Drive : $($Disk.DeviceID)"
            $Output += "Volume: $($Disk.VolumeName)"
            $Output += "Total : $Size GB"
            $Output += "Used  : $Used GB"
            $Output += "Free  : $Free GB"
            $Output += "Free% : $FreePercent%"
            $Output += ""
        }

        if ($Output.Count -eq 0) {

            return "No local disks found."
        }

        return (
            $Output -join "`r`n"
        )
    }
    catch {

        return "Unable to retrieve disk information."
    }
}

# ============================================================
# SECURE CHANNEL
# ============================================================

function Get-SecureChannelInfo {

    $Computer =
        Get-CimInstance Win32_ComputerSystem

    if (!$Computer.PartOfDomain) {

        return "Not applicable - computer is not domain joined."
    }

    try {

        $Healthy =
            Test-ComputerSecureChannel

        if ($Healthy) {

            return "HEALTHY`r`n`r`nThe computer secure channel is working correctly."
        }
        else {

            return "BROKEN`r`n`r`nThe computer secure channel may need repair."
        }
    }
    catch {

        return "Unable to test secure channel.`r`n`r`n$($_.Exception.Message)"
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
# CREATE DROPDOWN SECTION
# ============================================================
#
# IMPORTANT:
# This is the ONLY Add-Section function in the script.
#
# ============================================================

function Add-Section {

    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.FlowLayoutPanel]$Parent,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Content
    )

    # --------------------------------------------------------
    # SECTION PANEL
    # --------------------------------------------------------

    $SectionPanel =
        New-Object System.Windows.Forms.Panel

    $SectionPanel.Width = 780
    $SectionPanel.Height = 48

    $SectionPanel.Margin =
        New-Object System.Windows.Forms.Padding(
            0,0,0,8
        )

    $SectionPanel.BackColor =
        [System.Drawing.Color]::White

    $SectionPanel.BorderStyle =
        [System.Windows.Forms.BorderStyle]::FixedSingle

    # --------------------------------------------------------
    # DROPDOWN BUTTON
    # --------------------------------------------------------

    $Button =
        New-Object System.Windows.Forms.Button

    $Button.Text =
        "[+]  $Title"

    $Button.Location =
        New-Object System.Drawing.Point(
            1,1
        )

    $Button.Width = 776
    $Button.Height = 44

    $Button.FlatStyle =
        [System.Windows.Forms.FlatStyle]::Flat

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor =
        [System.Drawing.Color]::White

    $Button.ForeColor =
        $ColorText

    $Button.Font =
        New-Object System.Drawing.Font(
            "Segoe UI Semibold",
            10
        )

    $Button.TextAlign =
        [System.Drawing.ContentAlignment]::MiddleLeft

    $Button.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    # --------------------------------------------------------
    # CONTENT BOX
    # --------------------------------------------------------

    $ContentBox =
        New-Object System.Windows.Forms.RichTextBox

    $ContentBox.Text =
        $Content

    $ContentBox.ReadOnly = $true

    $ContentBox.BorderStyle =
        [System.Windows.Forms.BorderStyle]::None

    $ContentBox.BackColor =
        [System.Drawing.Color]::White

    $ContentBox.ForeColor =
        $ColorText

    $ContentBox.Font =
        New-Object System.Drawing.Font(
            "Consolas",
            9
        )

    $ContentBox.Location =
        New-Object System.Drawing.Point(
            15,50
        )

    $ContentBox.Width = 748

    $ContentBox.Height = 100

    $ContentBox.Visible = $false

    $ContentBox.ScrollBars =
        [System.Windows.Forms.RichTextBoxScrollBars]::Vertical

    # --------------------------------------------------------
    # STORE DATA IN BUTTON TAG
    # --------------------------------------------------------

    $Button.Tag = @{
        SectionPanel = $SectionPanel
        ContentBox   = $ContentBox
        Title        = $Title
    }

    # --------------------------------------------------------
    # ADD CONTROLS
    # --------------------------------------------------------

    [void]$SectionPanel.Controls.Add(
        $Button
    )

    [void]$SectionPanel.Controls.Add(
        $ContentBox
    )

    # --------------------------------------------------------
    # DROPDOWN CLICK EVENT
    # --------------------------------------------------------

    $Button.Add_Click({

        $Data =
            $this.Tag

        $Panel =
            $Data.SectionPanel

        $Box =
            $Data.ContentBox

        $SectionTitle =
            $Data.Title

        # ----------------------------------------------------
        # OPEN
        # ----------------------------------------------------

        if (!$Box.Visible) {

            # Count lines
            $LineCount =
                ($Box.Text -split "`r?`n").Count

            # Calculate height
            $NewHeight =
                ($LineCount * 18) + 35

            # Minimum
            if ($NewHeight -lt 110) {

                $NewHeight = 110
            }

            # Maximum
            if ($NewHeight -gt 450) {

                $NewHeight = 450
            }

            $Box.Height =
                $NewHeight - 60

            $Panel.Height =
                $NewHeight

            $Box.Visible = $true

            $this.Text =
                "[-]  $SectionTitle"
        }

        # ----------------------------------------------------
        # CLOSE
        # ----------------------------------------------------

        else {

            $Box.Visible = $false

            $Panel.Height = 48

            $this.Text =
                "[+]  $SectionTitle"
        }

        # ----------------------------------------------------
        # FORCE FLOW LAYOUT REFRESH
        # ----------------------------------------------------

        if ($Parent) {

            $Parent.SuspendLayout()

            $Parent.ResumeLayout(
                $true
            )

            $Parent.PerformLayout()

            $Parent.Refresh()
        }
    })

    # --------------------------------------------------------
    # ADD SECTION TO FLOW PANEL
    # --------------------------------------------------------

    [void]$Parent.Controls.Add(
        $SectionPanel
    )

    $Parent.PerformLayout()
}

# ============================================================
# CREATE MAIN FORM
# ============================================================

$Form =
    New-Object System.Windows.Forms.Form

$Form.Text =
    "Computer Information"

$Form.Width = 850
$Form.Height = 850

$Form.StartPosition =
    [System.Windows.Forms.FormStartPosition]::CenterScreen

$Form.BackColor =
    $ColorBackground

$Form.MinimumSize =
    New-Object System.Drawing.Size(
        700,
        700
    )

# ============================================================
# SCROLL AREA
# ============================================================

$ScrollPanel =
    New-Object System.Windows.Forms.Panel

$ScrollPanel.Dock =
    [System.Windows.Forms.DockStyle]::Fill

$ScrollPanel.AutoScroll = $true

$ScrollPanel.Padding =
    New-Object System.Windows.Forms.Padding(
        25,20,25,20
    )

$ScrollPanel.BackColor =
    $ColorBackground

[void]$Form.Controls.Add(
    $ScrollPanel
)

# ============================================================
# HEADER
# ============================================================

$Header =
    New-Object System.Windows.Forms.Panel

$Header.Dock =
    [System.Windows.Forms.DockStyle]::Top

$Header.Height = 155

$Header.BackColor =
    $ColorHeader

[void]$Form.Controls.Add(
    $Header
)

# Make sure header stays above scroll area
$Header.BringToFront()

# ============================================================
# DEVICE LABEL
# ============================================================

$DeviceLabel =
    New-Object System.Windows.Forms.Label

$DeviceLabel.Text =
    "DEVICE"

$DeviceLabel.Location =
    New-Object System.Drawing.Point(
        30,18
    )

$DeviceLabel.AutoSize = $true

$DeviceLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,163,184
    )

$DeviceLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

[void]$Header.Controls.Add(
    $DeviceLabel
)

# ============================================================
# DEVICE NAME
# ============================================================

$DeviceNameLabel =
    New-Object System.Windows.Forms.Label

$DeviceNameLabel.Location =
    New-Object System.Drawing.Point(
        28,40
    )

$DeviceNameLabel.AutoSize = $true

$DeviceNameLabel.ForeColor =
    $ColorWhite

$DeviceNameLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI Semibold",
        24
    )

[void]$Header.Controls.Add(
    $DeviceNameLabel
)

# ============================================================
# DOMAIN LABEL
# ============================================================

$DomainLabel =
    New-Object System.Windows.Forms.Label

$DomainLabel.Text =
    "DOMAIN"

$DomainLabel.Location =
    New-Object System.Drawing.Point(
        400,18
    )

$DomainLabel.AutoSize = $true

$DomainLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,163,184
    )

$DomainLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

[void]$Header.Controls.Add(
    $DomainLabel
)

# ============================================================
# DOMAIN VALUE
# ============================================================

$DomainValueLabel =
    New-Object System.Windows.Forms.Label

$DomainValueLabel.Location =
    New-Object System.Drawing.Point(
        398,40
    )

$DomainValueLabel.AutoSize = $true

$DomainValueLabel.MaximumSize =
    New-Object System.Drawing.Size(
        390,
        0
    )

$DomainValueLabel.ForeColor =
    $ColorWhite

$DomainValueLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI Semibold",
        15
    )

[void]$Header.Controls.Add(
    $DomainValueLabel
)

# ============================================================
# OU LABEL
# ============================================================

$OULabel =
    New-Object System.Windows.Forms.Label

$OULabel.Text =
    "ORGANIZATIONAL UNIT"

$OULabel.Location =
    New-Object System.Drawing.Point(
        30,95
    )

$OULabel.AutoSize = $true

$OULabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,163,184
    )

$OULabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9
    )

[void]$Header.Controls.Add(
    $OULabel
)

# ============================================================
# OU VALUE
# ============================================================

$OUValueLabel =
    New-Object System.Windows.Forms.Label

$OUValueLabel.Location =
    New-Object System.Drawing.Point(
        30,115
    )

$OUValueLabel.AutoSize = $true

$OUValueLabel.MaximumSize =
    New-Object System.Drawing.Size(
        760,
        0
    )

$OUValueLabel.ForeColor =
    $ColorWhite

$OUValueLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

[void]$Header.Controls.Add(
    $OUValueLabel
)

# ============================================================
# REFRESH BUTTON
# ============================================================

$RefreshButton =
    New-Object System.Windows.Forms.Button

$RefreshButton.Text =
    "Refresh"

$RefreshButton.Width = 100
$RefreshButton.Height = 35

$RefreshButton.Location =
    New-Object System.Drawing.Point(
        720,20
    )

$RefreshButton.FlatStyle =
    [System.Windows.Forms.FlatStyle]::Flat

$RefreshButton.FlatAppearance.BorderSize = 0

$RefreshButton.BackColor =
    $ColorBlue

$RefreshButton.ForeColor =
    $ColorWhite

$RefreshButton.Font =
    New-Object System.Drawing.Font(
        "Segoe UI Semibold",
        9
    )

$RefreshButton.Cursor =
    [System.Windows.Forms.Cursors]::Hand

[void]$Header.Controls.Add(
    $RefreshButton
)

# ============================================================
# FLOW LAYOUT
# ============================================================

$Sections =
    New-Object System.Windows.Forms.FlowLayoutPanel

$Sections.FlowDirection =
    [System.Windows.Forms.FlowDirection]::TopDown

$Sections.WrapContents = $false

$Sections.AutoSize = $true

$Sections.AutoSizeMode =
    [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

$Sections.Dock =
    [System.Windows.Forms.DockStyle]::Top

$Sections.Padding =
    New-Object System.Windows.Forms.Padding(
        0,0,0,20
    )

$Sections.BackColor =
    $ColorBackground

[void]$ScrollPanel.Controls.Add(
    $Sections
)

# ============================================================
# LOAD INFORMATION
# ============================================================

function Load-Information {

    $RefreshButton.Enabled = $false

    $RefreshButton.Text =
        "Loading..."

    try {

        # ----------------------------------------------------
        # GET MAIN COMPUTER INFORMATION
        # ----------------------------------------------------

        $Info =
            Get-ComputerInformation

        # ----------------------------------------------------
        # UPDATE HEADER
        # ----------------------------------------------------

        $DeviceNameLabel.Text =
            $Info.ComputerName

        $DomainValueLabel.Text =
            $Info.Domain

        $OUValueLabel.Text =
            $Info.OU

        # ----------------------------------------------------
        # CLEAR OLD SECTIONS
        # ----------------------------------------------------

        $Sections.SuspendLayout()

        $Sections.Controls.Clear()

        # ----------------------------------------------------
        # COMPUTER
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
        # WINDOWS
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
        # HARDWARE
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
        # ACTIVE DIRECTORY
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
        # DOMAIN CONTROLLER
        # ----------------------------------------------------

        $DCInfo =
            Get-DomainControllerInfo

        Add-Section `
            -Parent $Sections `
            -Title "Domain Controller" `
            -Content $DCInfo

        # ----------------------------------------------------
        # SECURE CHANNEL
        # ----------------------------------------------------

        $SecureChannel =
            Get-SecureChannelInfo

        Add-Section `
            -Parent $Sections `
            -Title "Domain Secure Channel" `
            -Content $SecureChannel

        # ----------------------------------------------------
        # NETWORK
        # ----------------------------------------------------

        $NetworkInfo =
            Get-NetworkInfo

        Add-Section `
            -Parent $Sections `
            -Title "Network Adapters" `
            -Content $NetworkInfo

        # ----------------------------------------------------
        # DNS
        # ----------------------------------------------------

        $DNSInfo =
            Get-DNSInfo

        Add-Section `
            -Parent $Sections `
            -Title "DNS" `
            -Content $DNSInfo

        # ----------------------------------------------------
        # STORAGE
        # ----------------------------------------------------

        $DiskInfo =
            Get-DiskInfo

        Add-Section `
            -Parent $Sections `
            -Title "Storage" `
            -Content $DiskInfo

        # ----------------------------------------------------
        # GROUP POLICY
        # ----------------------------------------------------

        $GPInfo =
            Get-GroupPolicyInfo

        Add-Section `
            -Parent $Sections `
            -Title "Group Policy" `
            -Content $GPInfo

        $Sections.ResumeLayout(
            $true
        )

        $Sections.PerformLayout()
        $ScrollPanel.PerformLayout()

    }
    catch {

        $Sections.ResumeLayout(
            $true
        )

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load computer information.`r`n`r`n$($_.Exception.Message)",
            "Computer Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }

    $RefreshButton.Enabled = $true

    $RefreshButton.Text =
        "Refresh"
}

# ============================================================
# REFRESH EVENT
# ============================================================

$RefreshButton.Add_Click({

    Load-Information
})

# ============================================================
# FORM SHOWN EVENT
# ============================================================

$Form.Add_Shown({

    Load-Information
})

# ============================================================
# FORM CLOSE EVENT
# ============================================================

$Form.Add_FormClosed({

    # Restore console if this script was launched
    # from an existing PowerShell console.

    if ($ConsoleHandle -ne [IntPtr]::Zero) {

        [ConsoleWindow]::ShowWindow(
            $ConsoleHandle,
            5
        )
    }
})

# ============================================================
# RUN APPLICATION
# ============================================================

[void]$Form.ShowDialog()
