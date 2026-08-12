# ============================================================
# ADMIN TOOLKIT - MAIN MENU
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

$GitHubOwner  = "JJenkins0115"
$GitHubRepo   = "PS-Scripts"
$GitHubBranch = "main"

$ToolkitName = "Admin Toolkit"

$TempFolder = Join-Path $env:TEMP "AdminToolkit"

# ============================================================
# GITHUB URLS
# ============================================================

$GitHubAPI = "https://api.github.com/repos/$GitHubOwner/$GitHubRepo/git/trees/$GitHubBranch`?recursive=1"

$RawBase = "https://raw.githubusercontent.com/$GitHubOwner/$GitHubRepo/$GitHubBranch"
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

[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Stop"

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

# ============================================================
# GITHUB URLS
# ============================================================

$GitHubAPI = "https://api.github.com/repos/$GitHubOwner/$GitHubRepo/git/trees/$GitHubBranch`?recursive=1"

$RawBase = "https://raw.githubusercontent.com/$GitHubOwner/$GitHubRepo/$GitHubBranch"

# ============================================================
# CREATE TEMP FOLDER
# ============================================================

if (!(Test-Path $TempFolder)) {

    New-Item `
        -ItemType Directory `
        -Path $TempFolder `
        -Force |
        Out-Null
}

# ============================================================
# GET SCRIPT FILES FROM GITHUB
# ============================================================

function Get-GitHubScripts {

    try {

        $Headers = @{
            "User-Agent" = "AdminToolkit"
        }

        $RepositoryTree = Invoke-RestMethod `
            -Uri $GitHubAPI `
            -Headers $Headers `
            -Method Get

        if (!$RepositoryTree.tree) {

            throw "GitHub returned no repository files."
        }

        $Scripts = @()

        foreach ($Item in $RepositoryTree.tree) {

            if ($Item.type -ne "blob") {
                continue
            }

            if ($Item.path -notlike "*.ps1") {
                continue
            }

            # Do not display main.ps1 as a tool
            if ($Item.path -eq "main.ps1") {
                continue
            }

            $Parts = $Item.path -split "/"

            if ($Parts.Count -lt 2) {
                continue
            }

            $Folder = $Parts[0]

            $FileName = $Parts[-1]

            $RelativePath = $Item.path

            $RawURL = "$RawBase/$RelativePath"

            $Scripts += [PSCustomObject]@{

                Name         = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

                FileName     = $FileName

                Folder       = $Folder

                Path         = $RelativePath

                URL          = $RawURL

                SHA          = $Item.sha

            }
        }

        return $Scripts |
            Sort-Object Folder, Name
    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to retrieve scripts from GitHub.`r`n`r`n$($_.Exception.Message)",
            "GitHub Error",
            "OK",
            "Error"
        )

        return @()
    }
}

# ============================================================
# DOWNLOAD SCRIPT
# ============================================================

function Get-RemoteScript {

    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Script
    )

    $SafeName = $Script.FileName

    $LocalFile = Join-Path `
        $TempFolder `
        $SafeName

    try {

        $Headers = @{
            "User-Agent" = "AdminToolkit"
        }

        Invoke-WebRequest `
            -Uri $Script.URL `
            -Headers $Headers `
            -UseBasicParsing `
            -OutFile $LocalFile

        if (!(Test-Path $LocalFile)) {

            throw "The script was not downloaded."
        }

        return $LocalFile
    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to download:`r`n`r`n$($Script.Path)`r`n`r`n$($_.Exception.Message)",
            "Download Error",
            "OK",
            "Error"
        )

        return $null
    }
}

# ============================================================
# RUN SCRIPT AS ADMINISTRATOR
# ============================================================

function Start-Tool {

    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Script
    )

    $LocalFile = Get-RemoteScript $Script

    if (!$LocalFile) {
        return
    }

    try {

        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList @(
                "-NoProfile"
                "-ExecutionPolicy"
                "Bypass"
                "-File"
                "`"$LocalFile`""
            )

    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to start the selected script.`r`n`r`n$($_.Exception.Message)",
            "Launch Error",
            "OK",
            "Error"
        )
    }
}

# ============================================================
# CREATE SCRIPT BUTTON
# ============================================================

function New-ScriptButton {

    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Script
    )

    $Button = New-Object System.Windows.Forms.Button

    $Button.Width = 735
    $Button.Height = 48

    $Button.Margin = New-Object `
        System.Windows.Forms.Padding(
            0,
            0,
            0,
            8
        )

    $Button.Text = "▶  $($Script.Name)"

    $Button.TextAlign = "MiddleLeft"

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI Semibold",
            10
        )

    $Button.Cursor = `
        [System.Windows.Forms.Cursors]::Hand

    $Button.Tag = $Script

    $Button.Add_MouseEnter({

        $this.BackColor = `
            [System.Drawing.Color]::FromArgb(
                239,
                246,
                255
            )
    })

    $Button.Add_MouseLeave({

        $this.BackColor = $ColorWhite
    })

    $Button.Add_Click({

        $SelectedScript = $this.Tag

        Start-Tool $SelectedScript
    })

    return $Button
}

# ============================================================
# CREATE FOLDER HEADER
# ============================================================

function New-FolderHeader {

    param(
        [string]$FolderName
    )

    $Label = New-Object System.Windows.Forms.Label

    $Label.Text = $FolderName.ToUpper()

    $Label.Width = 735
    $Label.Height = 35

    $Label.Margin = New-Object `
        System.Windows.Forms.Padding(
            0,
            15,
            0,
            5
        )

    $Label.ForeColor = $ColorSubText

    $Label.Font = New-Object `
        System.Drawing.Font(
            "Segoe UI Semibold",
            9
        )

    return $Label
}

# ============================================================
# MAIN WINDOW
# ============================================================

$Form = New-Object System.Windows.Forms.Form

$Form.Text = $ToolkitName

$Form.Size = New-Object `
    System.Drawing.Size(
        850,
        850
    )

$Form.MinimumSize = New-Object `
    System.Drawing.Size(
        700,
        650
    )

$Form.StartPosition = "CenterScreen"

$Form.BackColor = $ColorBackground

# ============================================================
# HEADER
# ============================================================

$Header = New-Object System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 125

$Header.BackColor = $ColorHeader

$Form.Controls.Add($Header)

# ============================================================
# TITLE
# ============================================================

$TitleLabel = New-Object System.Windows.Forms.Label

$TitleLabel.Text = $ToolkitName

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

$SubtitleLabel = New-Object System.Windows.Forms.Label

$SubtitleLabel.Text = "Select a tool to run"

$SubtitleLabel.Location = New-Object `
    System.Drawing.Point(
        33,
        62
    )

$SubtitleLabel.AutoSize = $true

$SubtitleLabel.ForeColor = `
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
# REFRESH BUTTON
# ============================================================

$RefreshButton = New-Object `
    System.Windows.Forms.Button

$RefreshButton.Text = "Refresh"

$RefreshButton.Width = 100

$RefreshButton.Height = 35

$RefreshButton.Location = New-Object `
    System.Drawing.Point(
        710,
        25
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
# SCRIPT CONTAINER
# ============================================================

$ScriptPanel = New-Object `
    System.Windows.Forms.FlowLayoutPanel

$ScriptPanel.FlowDirection = "TopDown"

$ScriptPanel.WrapContents = $false

$ScriptPanel.AutoSize = $true

$ScriptPanel.AutoSizeMode = "GrowAndShrink"

$ScriptPanel.Dock = "Top"

$ScrollPanel.Controls.Add($ScriptPanel)

# ============================================================
# LOAD SCRIPTS
# ============================================================

function Load-Scripts {

    $RefreshButton.Enabled = $false

    $RefreshButton.Text = "Loading..."

    $ScriptPanel.SuspendLayout()

    try {

        $ScriptPanel.Controls.Clear()

        $Scripts = Get-GitHubScripts

        if (!$Scripts -or $Scripts.Count -eq 0) {

            $NoScripts = New-Object `
                System.Windows.Forms.Label

            $NoScripts.Text = @"
No PS1 files found.

Repository:
$GitHubOwner/$GitHubRepo

Branch:
$GitHubBranch
"@

            $NoScripts.Width = 735

            $NoScripts.Height = 100

            $NoScripts.ForeColor = $ColorText

            $NoScripts.Font = New-Object `
                System.Drawing.Font(
                    "Segoe UI",
                    11
                )

            $ScriptPanel.Controls.Add($NoScripts)

            return
        }

        # ----------------------------------------------------
        # Group scripts by folder
        # ----------------------------------------------------

        $Groups = $Scripts |
            Group-Object Folder

        foreach ($Group in $Groups) {

            $FolderHeader = New-FolderHeader `
                -FolderName $Group.Name

            $ScriptPanel.Controls.Add(
                $FolderHeader
            )

            foreach ($Script in $Group.Group) {

                $Button = New-ScriptButton `
                    -Script $Script

                $ScriptPanel.Controls.Add(
                    $Button
                )
            }
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

        $ScriptPanel.ResumeLayout()

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
# FORM SHOWN
# ============================================================

$Form.Add_Shown({

    Load-Scripts
})

# ============================================================
# RUN
# ============================================================

[void]$Form.ShowDialog()

# ============================================================
# CLEANUP
# ============================================================

try {

    if (Test-Path $TempFolder) {

        Remove-Item `
            -Path $TempFolder `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
catch {
}
