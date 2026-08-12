
# ============================================================
# ADMIN TOOLKIT - MAIN MENU
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# HIDE POWERSHELL CONSOLE
# ============================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ConsoleWindow {
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
    [ConsoleWindow]::ShowWindow($ConsoleHandle, 0)
}

# ============================================================
# LOAD WINDOWS FORMS
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# COLORS
# ============================================================

$ColorBackground = [System.Drawing.Color]::FromArgb(245,247,250)

$ColorHeader = [System.Drawing.Color]::FromArgb(
    30,41,59
)

$ColorBlue = [System.Drawing.Color]::FromArgb(
    37,99,235
)

$ColorText = [System.Drawing.Color]::FromArgb(
    30,41,59
)

$ColorSubText = [System.Drawing.Color]::FromArgb(
    100,116,139
)

$ColorWhite = [System.Drawing.Color]::White

$ColorHover = [System.Drawing.Color]::FromArgb(
    239,246,255
)

# ============================================================
# SCRIPT LOCATION
# ============================================================

$ScriptRoot = Split-Path -Parent $PSCommandPath

# ============================================================
# GET SCRIPT DISPLAY NAME
# ============================================================

function Get-ScriptDisplayName {

    param(
        [System.IO.FileInfo]$File
    )

    $Name = $File.BaseName

    # Remove common prefixes
    $Name = $Name -replace '^[0-9]+[-_ ]*',''

    # Add spaces between CamelCase words
    $Name = $Name -replace '([a-z])([A-Z])','$1 $2'

    # Replace separators
    $Name = $Name -replace '[_-]',' '

    return $Name.Trim()
}

# ============================================================
# GET SCRIPT CATEGORIES
# ============================================================

function Get-ScriptCategories {

    $Categories = @()

    # --------------------------------------------------------
    # Look through directories
    # --------------------------------------------------------

    $Folders = Get-ChildItem `
        -Path $ScriptRoot `
        -Directory `
        -ErrorAction SilentlyContinue |
        Sort-Object Name

    foreach ($Folder in $Folders) {

        # Don't treat hidden/system folders as categories
        if ($Folder.Name.StartsWith(".")) {
            continue
        }

        $Scripts = Get-ChildItem `
            -Path $Folder.FullName `
            -Filter "*.ps1" `
            -File `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ne "main.ps1"
            } |
            Sort-Object Name

        if ($Scripts.Count -gt 0) {

            $Categories += [PSCustomObject]@{
                Name    = $Folder.Name
                Scripts = @($Scripts)
            }
        }
    }

    # --------------------------------------------------------
    # Scripts directly in repository root
    # --------------------------------------------------------

    $RootScripts = Get-ChildItem `
        -Path $ScriptRoot `
        -Filter "*.ps1" `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -ne "main.ps1"
        } |
        Sort-Object Name

    if ($RootScripts.Count -gt 0) {

        $Categories = @(
            [PSCustomObject]@{
                Name    = "General"
                Scripts = @($RootScripts)
            }
        ) + $Categories
    }

    return $Categories
}

# ============================================================
# LAUNCH SCRIPT
# ============================================================

function Start-ToolScript {

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {

        [System.Windows.Forms.MessageBox]::Show(
            "The script could not be found:`r`n`r`n$Path",
            "Script Not Found",
            "OK",
            "Error"
        )

        return
    }

    # --------------------------------------------------------
    # Confirm launch
    # --------------------------------------------------------

    $ScriptName = Split-Path $Path -Leaf

    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Run the following script?`r`n`r`n$ScriptName",
        "Run Script",
        "YesNo",
        "Question"
    )

    if ($Result -ne "Yes") {
        return
    }

    # --------------------------------------------------------
    # Launch elevated PowerShell
    # --------------------------------------------------------

    try {

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$Path`""
            )

    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to start the script.`r`n`r`n$($_.Exception.Message)",
            "Launch Error",
            "OK",
            "Error"
        )
    }
}

# ============================================================
# CREATE SCRIPT BUTTON
# ============================================================

function Add-ScriptButton {

    param(
        [System.Windows.Forms.Panel]$Parent,
        [System.IO.FileInfo]$Script
    )

    $Button = New-Object System.Windows.Forms.Button

    $Button.Text = "    $(
        Get-ScriptDisplayName $Script
    )"

    $Button.Width = 700

    $Button.Height = 42

    $Button.Margin = New-Object `
        System.Windows.Forms.Padding(
            20,
            2,
            20,
            2
        )

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI",
            10
        )

    $Button.TextAlign = "MiddleLeft"

    $Button.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    $Button.Tag = $Script.FullName

    # --------------------------------------------------------
    # Hover
    # --------------------------------------------------------

    $Button.Add_MouseEnter({

        $this.BackColor = $ColorHover
        $this.ForeColor = $ColorBlue

    })

    $Button.Add_MouseLeave({

        $this.BackColor = $ColorWhite
        $this.ForeColor = $ColorText

    })

    # --------------------------------------------------------
    # Click
    # --------------------------------------------------------

    $Button.Add_Click({

        Start-ToolScript `
            -Path $this.Tag

    })

    $Parent.Controls.Add($Button)
}

# ============================================================
# CREATE DROPDOWN CATEGORY
# ============================================================

function Add-Category {

    param(
        [System.Windows.Forms.FlowLayoutPanel]$Parent,
        [string]$Title,
        [array]$Scripts
    )

    # --------------------------------------------------------
    # Category container
    # --------------------------------------------------------

    $Panel = New-Object `
        System.Windows.Forms.Panel

    $Panel.Width = 740

    $Panel.Height = 50

    $Panel.Margin = New-Object `
        System.Windows.Forms.Padding(
            0,
            0,
            0,
            8
        )

    $Panel.BackColor = $ColorWhite

    # --------------------------------------------------------
    # Category button
    # --------------------------------------------------------

    $Button = New-Object `
        System.Windows.Forms.Button

    $Button.Text = "+  $Title"

    $Button.Width = 720

    $Button.Height = 44

    $Button.Location = New-Object `
        System.Drawing.Point(
            10,
            3
        )

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI Semibold",
            11
        )

    $Button.TextAlign = "MiddleLeft"

    $Button.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    # --------------------------------------------------------
    # Script container
    # --------------------------------------------------------

    $ScriptPanel = New-Object `
        System.Windows.Forms.FlowLayoutPanel

    $ScriptPanel.FlowDirection =
        "TopDown"

    $ScriptPanel.WrapContents = $false

    $ScriptPanel.AutoSize = $true

    $ScriptPanel.AutoSizeMode =
        "GrowAndShrink"

    $ScriptPanel.Location = New-Object `
        System.Drawing.Point(
            10,
            48
        )

    $ScriptPanel.Width = 720

    $ScriptPanel.Visible = $false

    $ScriptPanel.BackColor = $ColorWhite

    # --------------------------------------------------------
    # Add scripts
    # --------------------------------------------------------

    foreach ($Script in $Scripts) {

        Add-ScriptButton `
            -Parent $ScriptPanel `
            -Script $Script
    }

    # --------------------------------------------------------
    # Store references
    # --------------------------------------------------------

    $Button.Tag = @{
        Panel  = $Panel
        Scripts = $ScriptPanel
        Title  = $Title
    }

    # --------------------------------------------------------
    # Add controls
    # --------------------------------------------------------

    $Panel.Controls.Add($Button)

    $Panel.Controls.Add($ScriptPanel)

    # --------------------------------------------------------
    # Click category
    # --------------------------------------------------------

    $Button.Add_Click({

        $Data = $this.Tag

        $CategoryPanel = $Data.Panel

        $ScriptsPanel = $Data.Scripts

        $CategoryTitle = $Data.Title

        if (!$ScriptsPanel.Visible) {

            # ------------------------------------------------
            # OPEN
            # ------------------------------------------------

            $ScriptsPanel.Visible = $true

            $ScriptCount = $ScriptsPanel.Controls.Count

            $CategoryPanel.Height =
                55 + ($ScriptCount * 46)

            $this.Text =
                "-  $CategoryTitle"

        }
        else {

            # ------------------------------------------------
            # CLOSE
            # ------------------------------------------------

            $ScriptsPanel.Visible = $false

            $CategoryPanel.Height = 50

            $this.Text =
                "+  $CategoryTitle"
        }

        $Parent.PerformLayout()

        $Parent.Refresh()
    })

    $Parent.Controls.Add($Panel)
}

# ============================================================
# MAIN FORM
# ============================================================

$Form = New-Object `
    System.Windows.Forms.Form

$Form.Text = "Admin Toolkit"

$Form.Size = New-Object `
    System.Drawing.Size(
        850,
        850
    )

$Form.MinimumSize = New-Object `
    System.Drawing.Size(
        700,
        700
    )

$Form.StartPosition = "CenterScreen"

$Form.BackColor = $ColorBackground

# ============================================================
# HEADER
# ============================================================

$Header = New-Object `
    System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 140

$Header.BackColor = $ColorHeader

$Form.Controls.Add($Header)

# ============================================================
# TITLE
# ============================================================

$TitleLabel = New-Object `
    System.Windows.Forms.Label

$TitleLabel.Text = "ADMIN TOOLKIT"

$TitleLabel.Location = New-Object `
    System.Drawing.Point(
        30,
        20
    )

$TitleLabel.AutoSize = $true

$TitleLabel.ForeColor = $ColorWhite

$TitleLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI Semibold",
        24
    )

$Header.Controls.Add($TitleLabel)

# ============================================================
# SUBTITLE
# ============================================================

$SubtitleLabel = New-Object `
    System.Windows.Forms.Label

$SubtitleLabel.Text =
    "Select a category and choose a tool"

$SubtitleLabel.Location = New-Object `
    System.Drawing.Point(
        32,
        62
    )

$SubtitleLabel.AutoSize = $true

$SubtitleLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,
        163,
        184
    )

$SubtitleLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        10
    )

$Header.Controls.Add($SubtitleLabel)

# ============================================================
# REPOSITORY PATH
# ============================================================

$PathLabel = New-Object `
    System.Windows.Forms.Label

$PathLabel.Text =
    "Toolkit: $ScriptRoot"

$PathLabel.Location = New-Object `
    System.Drawing.Point(
        32,
        95
    )

$PathLabel.AutoSize = $true

$PathLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,
        163,
        184
    )

$PathLabel.Font = New-Object `
    System.Drawing.Font(
        "Segoe UI",
        8
    )

$Header.Controls.Add($PathLabel)

# ============================================================
# REFRESH BUTTON
# ============================================================

$RefreshButton = New-Object `
    System.Windows.Forms.Button

$RefreshButton.Text = "Refresh"

$RefreshButton.Width = 100

$RefreshButton.Height = 35

$RefreshButton.Location = New-Object `
    System.Drawing.Point(
        720,
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

$RefreshButton.Cursor =
    [System.Windows.Forms.Cursors]::Hand

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

$Sections.AutoSizeMode =
    "GrowAndShrink"

$Sections.Dock = "Top"

$Sections.BackColor = $ColorBackground

$ScrollPanel.Controls.Add($Sections)

# ============================================================
# LOAD SCRIPTS
# ============================================================

function Load-Scripts {

    $RefreshButton.Enabled = $false

    $RefreshButton.Text = "Loading..."

    try {

        $Sections.SuspendLayout()

        $Sections.Controls.Clear()

        # ----------------------------------------------------
        # Find categories
        # ----------------------------------------------------

        $Categories = Get-ScriptCategories

        # ----------------------------------------------------
        # No scripts
        # ----------------------------------------------------

        if ($Categories.Count -eq 0) {

            $Label = New-Object `
                System.Windows.Forms.Label

            $Label.Text =
                "No PowerShell scripts were found."

            $Label.AutoSize = $true

            $Label.Font = New-Object `
                System.Drawing.Font(
                    "Segoe UI",
                    11
                )

            $Label.ForeColor = $ColorSubText

            $Sections.Controls.Add($Label)

        }

        # ----------------------------------------------------
        # Add categories
        # ----------------------------------------------------

        foreach ($Category in $Categories) {

            Add-Category `
                -Parent $Sections `
                -Title $Category.Name `
                -Scripts $Category.Scripts
        }

    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load scripts.`r`n`r`n$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        )
    }
    finally {

        $Sections.ResumeLayout()

        $RefreshButton.Enabled = $true

        $RefreshButton.Text = "Refresh"
    }
}

# ============================================================
# REFRESH
# ============================================================

$RefreshButton.Add_Click({

    Load-Scripts

})

# ============================================================
# FORM LOAD
# ============================================================

$Form.Add_Shown({

    Load-Scripts

})

# ============================================================
# RUN APPLICATION
# ============================================================

[void]$Form.ShowDialog()
