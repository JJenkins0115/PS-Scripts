# ============================================================
# ADMIN TOOLKIT - MAIN GUI
# ============================================================
#
# Launch with:
#
# irm "https://raw.githubusercontent.com/JJenkins0115/PS-Scripts/refs/heads/main/Main.ps1" | iex
#
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# GITHUB SETTINGS
# ============================================================

$GitHubUser       = "JJenkins0115"
$GitHubRepository = "PS-Scripts"
$GitHubBranch     = "main"

# Leave blank if your folders are directly under the repository
$ScriptRootFolder = ""

# Main launcher
$MainScriptName   = "Main.ps1"

# Temporary local folder
$TempFolderName   = "AdminToolKit"
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

$ColorBlueHover = [System.Drawing.Color]::FromArgb(
    29,78,216
)

$ColorText = [System.Drawing.Color]::FromArgb(
    30,41,59
)

$ColorSubText = [System.Drawing.Color]::FromArgb(
    100,116,139
)

$ColorWhite = [System.Drawing.Color]::White

$ColorGreen = [System.Drawing.Color]::FromArgb(
    22,163,74
)

$ColorRed = [System.Drawing.Color]::FromArgb(
    220,38,38
)

$ColorConsole = [System.Drawing.Color]::FromArgb(
    15,23,42
)

# ============================================================
# GITHUB URLS
# ============================================================

$GitHubApiURL = "https://api.github.com/repos/$GitHubUser/$GitHubRepository/git/trees/$GitHubBranch?recursive=1"

$GitHubRawBase = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepository/refs/heads/$GitHubBranch"

# ============================================================
# TEMP DIRECTORY
# ============================================================

$TempRoot = Join-Path $env:TEMP $TempFolderName

if (!(Test-Path $TempRoot)) {

    New-Item `
        -ItemType Directory `
        -Path $TempRoot `
        -Force |
        Out-Null
}

# ============================================================
# GLOBAL VARIABLES
# ============================================================

$script:RepositoryFiles = @()

$script:CurrentFolder = ""

$script:CurrentScript = $null

# ============================================================
# CREATE MAIN FORM
# ============================================================

$Form = New-Object System.Windows.Forms.Form

$Form.Text = "Admin Toolkit"

$Form.Size = New-Object System.Drawing.Size(
    1000,
    750
)

$Form.MinimumSize = New-Object System.Drawing.Size(
    850,
    600
)

$Form.StartPosition = "CenterScreen"

$Form.BackColor = $ColorBackground

# ============================================================
# HEADER
# ============================================================

$Header = New-Object System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 115

$Header.BackColor = $ColorHeader

$Form.Controls.Add($Header)

# ============================================================
# TITLE
# ============================================================

$TitleLabel = New-Object System.Windows.Forms.Label

$TitleLabel.Text = "ADMIN TOOLKIT"

$TitleLabel.Location = New-Object System.Drawing.Point(
    30,
    18
)

$TitleLabel.AutoSize = $true

$TitleLabel.ForeColor = $ColorWhite

$TitleLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    24
)

$Header.Controls.Add($TitleLabel)

# ============================================================
# SUBTITLE
# ============================================================

$SubtitleLabel = New-Object System.Windows.Forms.Label

$SubtitleLabel.Text = "PowerShell Administration Tools"

$SubtitleLabel.Location = New-Object System.Drawing.Point(
    32,
    60
)

$SubtitleLabel.AutoSize = $true

$SubtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(
    148,163,184
)

$SubtitleLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    10
)

$Header.Controls.Add($SubtitleLabel)

# ============================================================
# REFRESH BUTTON
# ============================================================

$RefreshButton = New-Object System.Windows.Forms.Button

$RefreshButton.Text = "Refresh"

$RefreshButton.Width = 100

$RefreshButton.Height = 35

$RefreshButton.Location = New-Object System.Drawing.Point(
    850,
    25
)

$RefreshButton.FlatStyle = "Flat"

$RefreshButton.FlatAppearance.BorderSize = 0

$RefreshButton.BackColor = $ColorBlue

$RefreshButton.ForeColor = $ColorWhite

$RefreshButton.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    9
)

$RefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand

$Header.Controls.Add($RefreshButton)

# ============================================================
# BACK BUTTON
# ============================================================

$BackButton = New-Object System.Windows.Forms.Button

$BackButton.Text = "<  Back"

$BackButton.Width = 100

$BackButton.Height = 35

$BackButton.Location = New-Object System.Drawing.Point(
    735,
    25
)

$BackButton.FlatStyle = "Flat"

$BackButton.FlatAppearance.BorderSize = 0

$BackButton.BackColor = [System.Drawing.Color]::FromArgb(
    71,85,105
)

$BackButton.ForeColor = $ColorWhite

$BackButton.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    9
)

$BackButton.Visible = $false

$Header.Controls.Add($BackButton)

# ============================================================
# STATUS LABEL
# ============================================================

$StatusLabel = New-Object System.Windows.Forms.Label

$StatusLabel.Text = "Loading repository..."

$StatusLabel.Location = New-Object System.Drawing.Point(
    32,
    88
)

$StatusLabel.AutoSize = $true

$StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(
    148,163,184
)

$StatusLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    8
)

$Header.Controls.Add($StatusLabel)

# ============================================================
# MAIN CONTENT PANEL
# ============================================================

$MainPanel = New-Object System.Windows.Forms.Panel

$MainPanel.Dock = "Fill"

$MainPanel.AutoScroll = $true

$MainPanel.BackColor = $ColorBackground

$MainPanel.Padding = New-Object System.Windows.Forms.Padding(
    25,20,25,20
)

$Form.Controls.Add($MainPanel)

$MainPanel.BringToFront()

# ============================================================
# TITLE FOR CURRENT VIEW
# ============================================================

$ViewTitle = New-Object System.Windows.Forms.Label

$ViewTitle.Text = "Available Tools"

$ViewTitle.Location = New-Object System.Drawing.Point(
    25,
    20
)

$ViewTitle.AutoSize = $true

$ViewTitle.ForeColor = $ColorText

$ViewTitle.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    18
)

$MainPanel.Controls.Add($ViewTitle)

# ============================================================
# DESCRIPTION
# ============================================================

$ViewDescription = New-Object System.Windows.Forms.Label

$ViewDescription.Text = "Select a category or tool below."

$ViewDescription.Location = New-Object System.Drawing.Point(
    27,
    55
)

$ViewDescription.AutoSize = $true

$ViewDescription.ForeColor = $ColorSubText

$ViewDescription.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    9
)

$MainPanel.Controls.Add($ViewDescription)

# ============================================================
# BUTTON CONTAINER
# ============================================================

$ButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel

$ButtonPanel.Location = New-Object System.Drawing.Point(
    25,
    90
)

$ButtonPanel.Width = 900

$ButtonPanel.Height = 500

$ButtonPanel.FlowDirection = "TopDown"

$ButtonPanel.WrapContents = $false

$ButtonPanel.AutoScroll = $false

$ButtonPanel.BackColor = $ColorBackground

$MainPanel.Controls.Add($ButtonPanel)

# ============================================================
# CREATE TOOL BUTTON
# ============================================================

function New-ToolButton {

    param(
        [string]$Text,
        [string]$Description,
        [scriptblock]$Action
    )

    $Button = New-Object System.Windows.Forms.Button

    $Button.Text = "$Text`r`n$Description"

    $Button.Width = 850

    $Button.Height = 65

    $Button.Margin = New-Object System.Windows.Forms.Padding(
        0,0,0,10
    )

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

    $Button.TextAlign = "MiddleLeft"

    $Button.Padding = New-Object System.Windows.Forms.Padding(
        18,0,0,0
    )

    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand

    $Button.Add_MouseEnter({

        $this.BackColor = [System.Drawing.Color]::FromArgb(
            239,246,255
        )

    })

    $Button.Add_MouseLeave({

        $this.BackColor = $ColorWhite

    })

    if ($Action) {

        $Button.Add_Click($Action)

    }

    return $Button
}

# ============================================================
# GET FILES FROM GITHUB
# ============================================================

function Get-RepositoryFiles {

    try {

        $ApiUrl = "https://api.github.com/repos/$GitHubUser/$GitHubRepository/contents"

        if (![string]::IsNullOrWhiteSpace($ScriptRootFolder)) {

            $ApiUrl = "$ApiUrl/$ScriptRootFolder"

        }

        $ApiUrl = "$ApiUrl`?ref=$GitHubBranch"

        Write-Host "Connecting to GitHub..." -ForegroundColor Cyan

        $Headers = @{
            "User-Agent" = "PowerShell-AdminToolKit"
            "Accept"     = "application/vnd.github+json"
        }

        $RootItems = Invoke-RestMethod `
            -Uri $ApiUrl `
            -Headers $Headers `
            -Method Get `
            -UseBasicParsing `
            -ErrorAction Stop

        $Files = @()

        foreach ($Item in @($RootItems)) {

            # ------------------------------------------------
            # FILE
            # ------------------------------------------------

            if ($Item.type -eq "file") {

                if ($Item.name -like "*.ps1") {

                    $Files += [PSCustomObject]@{
                        Name        = $Item.name
                        Path        = $Item.path
                        DownloadUrl = $Item.download_url
                        Type        = "file"
                    }

                }

            }

            # ------------------------------------------------
            # FOLDER
            # ------------------------------------------------

            elseif ($Item.type -eq "dir") {

                try {

                    $FolderItems = Invoke-RestMethod `
                        -Uri "$($Item.url)?ref=$GitHubBranch" `
                        -Headers $Headers `
                        -Method Get `
                        -UseBasicParsing `
                        -ErrorAction Stop

                    foreach ($FolderItem in @($FolderItems)) {

                        if (
                            $FolderItem.type -eq "file" -and
                            $FolderItem.name -like "*.ps1"
                        ) {

                            $Files += [PSCustomObject]@{
                                Name        = $FolderItem.name
                                Path        = $FolderItem.path
                                DownloadUrl = $FolderItem.download_url
                                Type        = "file"
                            }

                        }

                    }

                }
                catch {

                    Write-Warning `
                        "Unable to read folder: $($Item.name)"

                }

            }

        }

        if ($Files.Count -eq 0) {

            throw "GitHub connected successfully, but no PS1 files were found."

        }

        return @($Files)

    }
    catch {

        throw "Unable to retrieve scripts from GitHub.`r`n`r`n$($_.Exception.Message)"

    }

}
# ============================================================
# CLEAR BUTTONS
# ============================================================

function Clear-ToolButtons {

    $ButtonPanel.Controls.Clear()

}

# ============================================================
# SHOW MAIN CATEGORIES
# ============================================================

function Show-Categories {

    $script:CurrentFolder = ""
    $script:CurrentScript = $null

    $BackButton.Visible = $false

    $ViewTitle.Text = "Available Tools"

    $ViewDescription.Text =
        "Select a category or PowerShell tool."

    Clear-ToolButtons

    if (
        $null -eq $script:RepositoryFiles -or
        $script:RepositoryFiles.Count -eq 0
    ) {

        $EmptyButton = New-ToolButton `
            -Text "No PowerShell Scripts Found" `
            -Description "Check your GitHub repository structure."

        $ButtonPanel.Controls.Add($EmptyButton)

        return
    }

    # --------------------------------------------------------
    # FIND TOP-LEVEL FOLDERS
    # --------------------------------------------------------

    $Folders = @()

    foreach ($File in $script:RepositoryFiles) {

        $Parts = $File.Path -split "/"

        if ($Parts.Count -gt 1) {

            $Folder = $Parts[0]

            if ($Folders -notcontains $Folder) {

                $Folders += $Folder

            }
        }
    }

    # --------------------------------------------------------
    # SHOW FOLDERS
    # --------------------------------------------------------

    foreach ($Folder in ($Folders | Sort-Object)) {

        $FolderPath = $Folder

        $Count = @(
            $script:RepositoryFiles |
            Where-Object {
                $_.Path.StartsWith(
                    "$FolderPath/",
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
        ).Count

        $Button = New-ToolButton `
            -Text $Folder `
            -Description "$Count PowerShell tool(s)"

        $Button.Add_Click({

            Show-Folder -Folder $FolderPath

        }.GetNewClosure())

        $ButtonPanel.Controls.Add($Button)
    }

    # --------------------------------------------------------
    # SHOW SCRIPTS IN ROOT OF REPOSITORY
    # --------------------------------------------------------

    $RootScripts = @(
        $script:RepositoryFiles |
        Where-Object {
            $_.Path -notmatch "/"
        }
    )

    foreach ($ScriptFile in ($RootScripts | Sort-Object Path)) {

        $ScriptItem = $ScriptFile

        $Button = New-ToolButton `
            -Text $ScriptFile.Name `
            -Description "PowerShell Script"

        $Button.Add_Click({

            Run-RepositoryScript -Script $ScriptItem

        }.GetNewClosure())

        $ButtonPanel.Controls.Add($Button)
    }
}
# ============================================================
# RUN SCRIPT
# ============================================================

function Run-RepositoryScript {

    param(
        [Parameter(Mandatory)]
        [psobject]$Script
    )

    $script:CurrentScript = $Script

    # --------------------------------------------------------
    # DOWNLOAD SCRIPT
    # --------------------------------------------------------

    $StatusLabel.Text =
        "Downloading $($Script.Name)..."

    try {

        $SafeName = [IO.Path]::GetFileName(
            $Script.Path
        )

        $LocalScript = Join-Path `
            $TempRoot `
            $SafeName

        Invoke-WebRequest `
            -Uri $Script.URL `
            -OutFile $LocalScript `
            -UseBasicParsing

    }
    catch {

        [System.Windows.Forms.MessageBox]::Show(
            "Unable to download the selected script.`r`n`r`n$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        ) | Out-Null

        $StatusLabel.Text =
            "$($script:RepositoryFiles.Count) PowerShell tool(s) found"

        return
    }

    # --------------------------------------------------------
    # SWITCH TO SCRIPT VIEW
    # --------------------------------------------------------

    Show-ScriptRunner `
        -Script $Script `
        -LocalScript $LocalScript
}

# ============================================================
# SCRIPT RUNNER
# ============================================================

function Show-ScriptRunner {

    param(
        [psobject]$Script,
        [string]$LocalScript
    )

    $BackButton.Visible = $true

    $ViewTitle.Text = $Script.Name

    $ViewDescription.Text =
        $Script.Path

    Clear-ToolButtons

    # --------------------------------------------------------
    # OUTPUT BOX
    # --------------------------------------------------------

    $OutputBox = New-Object System.Windows.Forms.RichTextBox

    $OutputBox.Location = New-Object System.Drawing.Point(
        0,
        0
    )

    $OutputBox.Width = 850

    $OutputBox.Height = 450

    $OutputBox.BackColor = $ColorConsole

    $OutputBox.ForeColor = [System.Drawing.Color]::FromArgb(
        226,232,240
    )

    $OutputBox.Font = New-Object System.Drawing.Font(
        "Consolas",
        9
    )

    $OutputBox.ReadOnly = $true

    $OutputBox.BorderStyle = "None"

    $OutputBox.ScrollBars = "Both"

    $ButtonPanel.Controls.Add($OutputBox)

    # --------------------------------------------------------
    # RUN BUTTON
    # --------------------------------------------------------

    $RunButton = New-ToolButton `
        -Text "Run Script" `
        -Description "Execute this PowerShell script"

    $RunButton.Width = 850

    $RunButton.Height = 65

    $ButtonPanel.Controls.Add($RunButton)

    # --------------------------------------------------------
    # STATUS
    # --------------------------------------------------------

    $OutputBox.AppendText(
        "============================================================`r`n"
    )

    $OutputBox.AppendText(
        " Admin Toolkit`r`n"
    )

    $OutputBox.AppendText(
        "============================================================`r`n`r`n"
    )

    $OutputBox.AppendText(
        "Script: $($Script.Name)`r`n"
    )

    $OutputBox.AppendText(
        "Path  : $($Script.Path)`r`n`r`n"
    )

    $OutputBox.AppendText(
        "Click 'Run Script' to execute.`r`n"
    )

    # --------------------------------------------------------
    # RUN EVENT
    # --------------------------------------------------------

    $RunButton.Add_Click({

        $RunButton.Enabled = $false

        $RunButton.Text =
            "Running..."

        $OutputBox.AppendText(
            "`r`n============================================================`r`n"
        )

        $OutputBox.AppendText(
            " Starting script...`r`n"
        )

        $OutputBox.AppendText(
            "============================================================`r`n`r`n"
        )

        try {

            # ------------------------------------------------
            # EXECUTE IN CURRENT POWERSHELL PROCESS
            # ------------------------------------------------
            #
            # This means normal Write-Host / Write-Output
            # goes into the application rather than creating
            # another PowerShell window.
            #
            # ------------------------------------------------

            $OldProgressPreference = $ProgressPreference

            $ProgressPreference = "SilentlyContinue"

            $Output = & $LocalScript *>&1 |
                Out-String

            $ProgressPreference = $OldProgressPreference

            if ($Output) {

                $OutputBox.AppendText(
                    $Output
                )

            }

            $OutputBox.AppendText(
                "`r`n============================================================`r`n"
            )

            $OutputBox.AppendText(
                " Script completed.`r`n"
            )

            $OutputBox.AppendText(
                "============================================================`r`n"
            )

        }
        catch {

            $OutputBox.AppendText(
                "`r`nERROR:`r`n"
            )

            $OutputBox.AppendText(
                "$($_.Exception.Message)`r`n"
            )

        }

        $RunButton.Enabled = $true

        $RunButton.Text =
            "Run Script"

    }.GetNewClosure())
}

# ============================================================
# BACK BUTTON EVENT
# ============================================================

$BackButton.Add_Click({

    if ($script:CurrentFolder) {

        $Parts = $script:CurrentFolder -split "/"

        if ($Parts.Count -gt 1) {

            $ParentFolder = (
                $Parts[0..($Parts.Count - 2)]
            ) -join "/"

            Show-Folder -Folder $ParentFolder

        }
        else {

            Show-Categories

        }

    }
    else {

        Show-Categories

    }

})

# ============================================================
# REFRESH EVENT
# ============================================================

$RefreshButton.Add_Click({

    $RefreshButton.Enabled = $false

    if (Get-RepositoryFiles) {

        Show-Categories

    }

    $RefreshButton.Enabled = $true

})

# ============================================================
# FORM LOAD
# ============================================================

$Form.Add_Shown({

    Show-Categories

})

# ============================================================
# START APPLICATION
# ============================================================

[void]$Form.ShowDialog()

# ============================================================
# CLEANUP
# ============================================================

if ($TempRoot -and (Test-Path $TempRoot)) {

    Remove-Item `
        -Path $TempRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

}
