# ============================================================
# ADMIN TOOLKIT
# ============================================================
#
# GitHub-powered PowerShell administration menu
#
# Designed to run with:
#
# irm "https://raw.githubusercontent.com/USER/REPO/main/main.ps1" | iex
#
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# GITHUB CONFIGURATION
# ============================================================
#
# CHANGE THESE VALUES
#
# ============================================================

$GitHubUser = "JJenkins0115"

$GitHubRepo = "PS-Scripts"

$GitHubBranch = "main"

# JSON file containing the menu
$MenuFile = "scripts.json"

# Temporary working directory
$TempFolder = Join-Path $env:TEMP "AdminToolkit"

# ============================================================
# AUTOMATIC URLS
# ============================================================

$GitHubBaseUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/$GitHubBranch"

$MenuUrl = "$GitHubBaseUrl/$MenuFile"

# ============================================================
# HIDE POWERSHELL CONSOLE
# ============================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class AdminToolkitConsole
{
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(
        IntPtr hWnd,
        int nCmdShow
    );
}
"@

$ConsoleHandle = [AdminToolkitConsole]::GetConsoleWindow()

if ($ConsoleHandle -ne [IntPtr]::Zero)
{
    [AdminToolkitConsole]::ShowWindow(
        $ConsoleHandle,
        0
    )
}

# ============================================================
# WINDOWS FORMS
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

# ============================================================
# COLORS
# ============================================================

$ColorBackground = [System.Drawing.Color]::FromArgb(
    245,247,250
)

$ColorHeader = [System.Drawing.Color]::FromArgb(
    30,41,59
)

$ColorBlue = [System.Drawing.Color]::FromArgb(
    37,99,235
)

$ColorBlueDark = [System.Drawing.Color]::FromArgb(
    29,78,216
)

$ColorText = [System.Drawing.Color]::FromArgb(
    30,41,59
)

$ColorSubText = [System.Drawing.Color]::FromArgb(
    100,116,139
)

$ColorWhite = [System.Drawing.Color]::White

$ColorBorder = [System.Drawing.Color]::FromArgb(
    226,232,240
)

$ColorHover = [System.Drawing.Color]::FromArgb(
    239,246,255
)

# ============================================================
# GLOBAL DATA
# ============================================================

$script:MenuData = $null

# ============================================================
# CREATE TEMP DIRECTORY
# ============================================================

if (!(Test-Path $TempFolder))
{
    New-Item `
        -ItemType Directory `
        -Path $TempFolder `
        -Force |
        Out-Null
}

# ============================================================
# DOWNLOAD MENU
# ============================================================

function Get-MenuData
{
    try
    {
        $Response = Invoke-WebRequest `
            -Uri $MenuUrl `
            -UseBasicParsing `
            -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($Response.Content))
        {
            throw "scripts.json was empty."
        }

        $Data = $Response.Content | ConvertFrom-Json

        if ($null -eq $Data)
        {
            throw "Unable to parse scripts.json."
        }

        return $Data
    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to download the script menu.`r`n`r`n" +
            "URL:`r`n$MenuUrl`r`n`r`n" +
            "Error:`r`n$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        ) | Out-Null

        return $null
    }
}

# ============================================================
# DOWNLOAD SELECTED SCRIPT
# ============================================================

function Get-ScriptFromGitHub
{
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    try
    {
        # Convert Windows slashes to URL slashes
        $RelativePath = $RelativePath.Replace("\","/")

        $ScriptUrl = "$GitHubBaseUrl/$RelativePath"

        # Create safe local filename
        $FileName = Split-Path `
            $RelativePath `
            -Leaf

        $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"

        $LocalFile = Join-Path `
            $TempFolder `
            "${TimeStamp}_$FileName"

        Invoke-WebRequest `
            -Uri $ScriptUrl `
            -OutFile $LocalFile `
            -UseBasicParsing `
            -ErrorAction Stop

        if (!(Test-Path $LocalFile))
        {
            throw "Script download failed."
        }

        return $LocalFile
    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to download the selected script.`r`n`r`n" +
            "File:`r`n$RelativePath`r`n`r`n" +
            "Error:`r`n$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        ) | Out-Null

        return $null
    }
}

# ============================================================
# RUN SELECTED SCRIPT
# ============================================================

function Start-SelectedScript
{
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    try
    {
        if (!(Test-Path $ScriptPath))
        {
            throw "Script file does not exist."
        }

        # ====================================================
        # Launch the downloaded script as Administrator
        # ====================================================

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$ScriptPath`""
            ) `
            -ErrorAction Stop
    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to start the selected script.`r`n`r`n" +
            "$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        ) | Out-Null
    }
}

# ============================================================
# CREATE SCRIPT BUTTON
# ============================================================

function Add-ScriptButton
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.FlowLayoutPanel]$Parent,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$File
    )

    $Button = New-Object `
        System.Windows.Forms.Button

    $Button.Width = 700

    $Button.Height = 48

    $Button.Margin = New-Object `
        System.Windows.Forms.Padding(
            5,3,5,3
        )

    $Button.Text = "    $Name"

    $Button.TextAlign =
        [System.Drawing.ContentAlignment]::MiddleLeft

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 1

    $Button.FlatAppearance.BorderColor =
        $ColorBorder

    $Button.BackColor =
        $ColorWhite

    $Button.ForeColor =
        $ColorText

    $Button.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI Semibold",
            10
        )

    $Button.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    # Store script path
    $Button.Tag = @{
        Name = $Name
        File = $File
    }

    # ========================================================
    # Hover
    # ========================================================

    $Button.Add_MouseEnter({

        $this.BackColor = $ColorHover

    })

    $Button.Add_MouseLeave({

        $this.BackColor = $ColorWhite

    })

    # ========================================================
    # Click
    # ========================================================

    $Button.Add_Click({

        $ScriptName =
            $this.Tag.Name

        $ScriptFile =
            $this.Tag.File

        $Result = [System.Windows.Forms.MessageBox]::Show(
            "Run:`r`n`r`n$ScriptName`r`n`r`n" +
            "Script:`r`n$ScriptFile",
            "Run Script",
            "YesNo",
            "Question"
        )

        if ($Result -ne "Yes")
        {
            return
        }

        $this.Enabled = $false

        try
        {
            $LocalScript =
                Get-ScriptFromGitHub `
                    -RelativePath $ScriptFile

            if ($LocalScript)
            {
                Start-SelectedScript `
                    -ScriptPath $LocalScript
            }
        }
        finally
        {
            $this.Enabled = $true
        }

    })

    $Parent.Controls.Add($Button)
}

# ============================================================
# CREATE CATEGORY SECTION
# ============================================================

function Add-Category
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.FlowLayoutPanel]$Parent,

        [Parameter(Mandatory)]
        [string]$CategoryName,

        [Parameter(Mandatory)]
        $Scripts
    )

    # ========================================================
    # Category container
    # ========================================================

    $CategoryPanel = New-Object `
        System.Windows.Forms.Panel

    $CategoryPanel.Width = 720

    $CategoryPanel.Height = 50

    $CategoryPanel.Margin =
        New-Object System.Windows.Forms.Padding(
            0,0,0,8
        )

    $CategoryPanel.BackColor =
        $ColorWhite

    # ========================================================
    # Category button
    # ========================================================

    $CategoryButton = New-Object `
        System.Windows.Forms.Button

    $CategoryButton.Width = 700

    $CategoryButton.Height = 46

    $CategoryButton.Location =
        New-Object System.Drawing.Point(
            5,2
        )

    $CategoryButton.Text =
        "+  $CategoryName"

    $CategoryButton.TextAlign =
        [System.Drawing.ContentAlignment]::MiddleLeft

    $CategoryButton.FlatStyle =
        "Flat"

    $CategoryButton.FlatAppearance.BorderSize =
        0

    $CategoryButton.BackColor =
        $ColorWhite

    $CategoryButton.ForeColor =
        $ColorText

    $CategoryButton.Font =
        New-Object System.Drawing.Font(
            "Segoe UI Semibold",
            11
        )

    $CategoryButton.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    # ========================================================
    # Script container
    # ========================================================

    $ScriptPanel = New-Object `
        System.Windows.Forms.FlowLayoutPanel

    $ScriptPanel.FlowDirection =
        "TopDown"

    $ScriptPanel.WrapContents =
        $false

    $ScriptPanel.AutoSize =
        $true

    $ScriptPanel.AutoSizeMode =
        "GrowAndShrink"

    $ScriptPanel.Location =
        New-Object System.Drawing.Point(
            5,50
        )

    $ScriptPanel.Width = 700

    $ScriptPanel.Visible = $false

    $ScriptPanel.BackColor =
        $ColorWhite

    # ========================================================
    # Add scripts
    # ========================================================

    foreach ($Script in $Scripts)
    {
        if (
            $null -ne $Script.Name -and
            $null -ne $Script.File
        )
        {
            Add-ScriptButton `
                -Parent $ScriptPanel `
                -Name ([string]$Script.Name) `
                -File ([string]$Script.File)
        }
    }

    # ========================================================
    # Store references
    # ========================================================

    $CategoryButton.Tag = @{
        Panel = $CategoryPanel
        Scripts = $ScriptPanel
        Title = $CategoryName
    }

    # ========================================================
    # Add controls
    # ========================================================

    $CategoryPanel.Controls.Add(
        $CategoryButton
    )

    $CategoryPanel.Controls.Add(
        $ScriptPanel
    )

    # ========================================================
    # Category click
    # ========================================================

    $CategoryButton.Add_Click({

        $Data = $this.Tag

        $Panel =
            $Data.Panel

        $ScriptsPanel =
            $Data.Scripts

        $Title =
            $Data.Title

        if (!$ScriptsPanel.Visible)
        {
            $ScriptsPanel.Visible = $true

            $Panel.Height =
                $ScriptsPanel.PreferredSize.Height + 58

            $this.Text =
                "-  $Title"
        }
        else
        {
            $ScriptsPanel.Visible = $false

            $Panel.Height = 50

            $this.Text =
                "+  $Title"
        }

        $Parent.PerformLayout()
        $Parent.Refresh()

    })

    $Parent.Controls.Add(
        $CategoryPanel
    )
}

# ============================================================
# BUILD MENU
# ============================================================

function Build-Menu
{
    $Sections.Controls.Clear()

    if ($null -eq $script:MenuData)
    {
        return
    }

    foreach ($Property in $script:MenuData.PSObject.Properties)
    {
        $CategoryName =
            $Property.Name

        $Scripts =
            $Property.Value

        if ($null -eq $Scripts)
        {
            continue
        }

        Add-Category `
            -Parent $Sections `
            -CategoryName $CategoryName `
            -Scripts $Scripts
    }

    $Sections.PerformLayout()
    $ScrollPanel.PerformLayout()
    $ScrollPanel.Refresh()
}

# ============================================================
# LOAD / REFRESH MENU
# ============================================================

function Load-Menu
{
    $RefreshButton.Enabled = $false

    $RefreshButton.Text =
        "Loading..."

    try
    {
        $script:MenuData =
            Get-MenuData

        if ($null -ne $script:MenuData)
        {
            Build-Menu

            $StatusLabel.Text =
                "Connected to GitHub"

            $StatusLabel.ForeColor =
                [System.Drawing.Color]::FromArgb(
                    74,222,128
                )
        }
        else
        {
            $StatusLabel.Text =
                "Unable to load menu"

            $StatusLabel.ForeColor =
                [System.Drawing.Color]::FromArgb(
                    248,113,113
                )
        }
    }
    catch
    {
        $StatusLabel.Text =
            "Error loading menu"
    }

    $RefreshButton.Enabled = $true

    $RefreshButton.Text =
        "Refresh"
}

# ============================================================
# MAIN WINDOW
# ============================================================

$Form = New-Object `
    System.Windows.Forms.Form

$Form.Text =
    "Admin Toolkit"

$Form.Size =
    New-Object System.Drawing.Size(
        850,850
    )

$Form.MinimumSize =
    New-Object System.Drawing.Size(
        700,650
    )

$Form.StartPosition =
    "CenterScreen"

$Form.BackColor =
    $ColorBackground

$Form.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9
    )

# ============================================================
# HEADER
# ============================================================

$Header = New-Object `
    System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 150

$Header.BackColor =
    $ColorHeader

$Form.Controls.Add(
    $Header
)

# ============================================================
# TITLE
# ============================================================

$TitleLabel = New-Object `
    System.Windows.Forms.Label

$TitleLabel.Text =
    "ADMIN TOOLKIT"

$TitleLabel.Location =
    New-Object System.Drawing.Point(
        30,20
    )

$TitleLabel.AutoSize =
    $true

$TitleLabel.ForeColor =
    $ColorWhite

$TitleLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI Semibold",
        24
    )

$Header.Controls.Add(
    $TitleLabel
)

# ============================================================
# SUBTITLE
# ============================================================

$SubtitleLabel = New-Object `
    System.Windows.Forms.Label

$SubtitleLabel.Text =
    "Select a tool to run"

$SubtitleLabel.Location =
    New-Object System.Drawing.Point(
        32,62
    )

$SubtitleLabel.AutoSize =
    $true

$SubtitleLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,163,184
    )

$SubtitleLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

$Header.Controls.Add(
    $SubtitleLabel
)

# ============================================================
# STATUS
# ============================================================

$StatusLabel = New-Object `
    System.Windows.Forms.Label

$StatusLabel.Text =
    "Connecting..."

$StatusLabel.Location =
    New-Object System.Drawing.Point(
        32,105
    )

$StatusLabel.AutoSize =
    $true

$StatusLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
        148,163,184
    )

$StatusLabel.Font =
    New-Object System.Drawing.Font(
        "Segoe UI",
        9
    )

$Header.Controls.Add(
    $StatusLabel
)

# ============================================================
# REFRESH BUTTON
# ============================================================

$RefreshButton = New-Object `
    System.Windows.Forms.Button

$RefreshButton.Text =
    "Refresh"

$RefreshButton.Width =
    110

$RefreshButton.Height =
    38

$RefreshButton.Location =
    New-Object System.Drawing.Point(
        700,20
    )

$RefreshButton.FlatStyle =
    "Flat"

$RefreshButton.FlatAppearance.BorderSize =
    0

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

$Header.Controls.Add(
    $RefreshButton
)

# ============================================================
# REFRESH HOVER
# ============================================================

$RefreshButton.Add_MouseEnter({

    $this.BackColor =
        $ColorBlueDark

})

$RefreshButton.Add_MouseLeave({

    $this.BackColor =
        $ColorBlue

})

# ============================================================
# SCROLL PANEL
# ============================================================

$ScrollPanel = New-Object `
    System.Windows.Forms.Panel

$ScrollPanel.Dock =
    "Fill"

$ScrollPanel.AutoScroll =
    $true

$ScrollPanel.Padding =
    New-Object System.Windows.Forms.Padding(
        25,20,25,20
    )

$ScrollPanel.BackColor =
    $ColorBackground

$Form.Controls.Add(
    $ScrollPanel
)

# ============================================================
# SECTION FLOW PANEL
# ============================================================

$Sections = New-Object `
    System.Windows.Forms.FlowLayoutPanel

$Sections.FlowDirection =
    "TopDown"

$Sections.WrapContents =
    $false

$Sections.AutoSize =
    $true

$Sections.AutoSizeMode =
    "GrowAndShrink"

$Sections.Dock =
    "Top"

$Sections.Width =
    750

$Sections.Padding =
    New-Object System.Windows.Forms.Padding(
        0,0,0,20
    )

$ScrollPanel.Controls.Add(
    $Sections
)

# ============================================================
# REFRESH EVENT
# ============================================================

$RefreshButton.Add_Click({

    Load-Menu

})

# ============================================================
# FORM SHOWN
# ============================================================

$Form.Add_Shown({

    Load-Menu

})

# ============================================================
# CLEANUP TEMP FILES WHEN FORM CLOSES
# ============================================================

$Form.Add_FormClosed({

    try
    {
        if (Test-Path $TempFolder)
        {
            Get-ChildItem `
                -Path $TempFolder `
                -Filter "*.ps1" `
                -ErrorAction SilentlyContinue |
                Remove-Item `
                    -Force `
                    -ErrorAction SilentlyContinue
        }
    }
    catch
    {
    }

})

# ============================================================
# START APPLICATION
# ============================================================

[void]$Form.ShowDialog()
