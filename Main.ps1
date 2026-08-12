# ============================================================
# ADMIN TOOLKIT - MAIN LAUNCHER
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# CONFIGURATION
# CHANGE THESE VARIABLES FOR YOUR GITHUB REPOSITORY
# ============================================================

$GitHubOwner = "JJenkins0115"

$GitHubRepository = "PS-Scripts"

$GitHubBranch = "main"

# Folder inside the repository containing your scripts
$ScriptFolder = "Scripts"

# Raw GitHub location
$RepositoryRawBase =
    "https://raw.githubusercontent.com/$GitHubOwner/$GitHubRepository/refs/heads/$GitHubBranch"

# GitHub API location used to find scripts
$GitHubApiBase =
    "https://api.github.com/repos/$GitHubOwner/$GitHubRepository/contents"

# Temporary working directory
$TempFolder = Join-Path $env:TEMP "AdminToolKit"

# ============================================================
# LOAD WINDOWS FORMS
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

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

$ColorGreen = [System.Drawing.Color]::FromArgb(
    22,163,74
)

$ColorRed = [System.Drawing.Color]::FromArgb(
    220,38,38
)

$ColorPanel = [System.Drawing.Color]::White

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
# GET SCRIPT LIST FROM GITHUB
# ============================================================

function Get-GitHubScripts {

    try {

        $Url = "$GitHubApiBase/$ScriptFolder"

        $Headers = @{
            "User-Agent" = "AdminToolKit"
        }

        $Response = Invoke-RestMethod `
            -Uri $Url `
            -Headers $Headers `
            -Method Get

        $Scripts = $Response |
            Where-Object {
                $_.type -eq "file" -and
                $_.name -like "*.ps1"
            } |
            Sort-Object name

        return @($Scripts)

    }
    catch {

        throw "Unable to retrieve scripts from GitHub.`r`n`r`n$($_.Exception.Message)"
    }
}

# ============================================================
# DOWNLOAD SCRIPT
# ============================================================

function Get-GitHubScript {

    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $RawUrl =
        "$RepositoryRawBase/$ScriptFolder/$FileName"

    $LocalFile =
        Join-Path $TempFolder $FileName

    try {

        Invoke-WebRequest `
            -Uri $RawUrl `
            -OutFile $LocalFile `
            -UseBasicParsing

        if (!(Test-Path $LocalFile)) {

            throw "The script was not downloaded."
        }

        return $LocalFile

    }
    catch {

        throw "Unable to download $FileName.`r`n`r`n$($_.Exception.Message)"
    }
}

# ============================================================
# MAIN FORM
# ============================================================

$Form = New-Object System.Windows.Forms.Form

$Form.Text = "Admin ToolKit"

$Form.Size = New-Object System.Drawing.Size(
    1000,
    750
)

$Form.MinimumSize = New-Object System.Drawing.Size(
    800,
    600
)

$Form.StartPosition = "CenterScreen"

$Form.BackColor = $ColorBackground

# ============================================================
# HEADER
# ============================================================

$Header = New-Object System.Windows.Forms.Panel

$Header.Dock = "Top"

$Header.Height = 120

$Header.BackColor = $ColorHeader

$Form.Controls.Add($Header)

# ============================================================
# TITLE
# ============================================================

$TitleLabel = New-Object System.Windows.Forms.Label

$TitleLabel.Text = "Admin ToolKit"

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

$SubtitleLabel.Text =
    "$GitHubOwner / $GitHubRepository"

$SubtitleLabel.Location = New-Object System.Drawing.Point(
    32,
    58
)

$SubtitleLabel.AutoSize = $true

$SubtitleLabel.ForeColor =
    [System.Drawing.Color]::FromArgb(
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

$Header.Controls.Add($RefreshButton)

# ============================================================
# CONTENT PANEL
# ============================================================

$ContentPanel = New-Object System.Windows.Forms.Panel

$ContentPanel.Dock = "Fill"

$ContentPanel.AutoScroll = $true

$ContentPanel.Padding = New-Object System.Windows.Forms.Padding(
    30
)

$ContentPanel.BackColor = $ColorBackground

$Form.Controls.Add($ContentPanel)

# ============================================================
# SCRIPT LIST PANEL
# ============================================================

$ScriptListPanel = New-Object System.Windows.Forms.FlowLayoutPanel

$ScriptListPanel.FlowDirection =
    [System.Windows.Forms.FlowDirection]::TopDown

$ScriptListPanel.WrapContents = $false

$ScriptListPanel.AutoScroll = $false

$ScriptListPanel.AutoSize = $true

$ScriptListPanel.AutoSizeMode =
    [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

$ScriptListPanel.Dock = "Top"

$ContentPanel.Controls.Add($ScriptListPanel)

# ============================================================
# OUTPUT PANEL
# ============================================================

$OutputPanel = New-Object System.Windows.Forms.Panel

$OutputPanel.Dock = "Fill"

$OutputPanel.BackColor = $ColorBackground

$OutputPanel.Visible = $false

$Form.Controls.Add($OutputPanel)

# ============================================================
# OUTPUT HEADER
# ============================================================

$OutputHeader = New-Object System.Windows.Forms.Panel

$OutputHeader.Dock = "Top"

$OutputHeader.Height = 60

$OutputHeader.BackColor = $ColorHeader

$OutputPanel.Controls.Add($OutputHeader)

# ============================================================
# OUTPUT TITLE
# ============================================================

$OutputTitle = New-Object System.Windows.Forms.Label

$OutputTitle.Text = "Running Script"

$OutputTitle.Location = New-Object System.Drawing.Point(
    25,
    18
)

$OutputTitle.AutoSize = $true

$OutputTitle.ForeColor = $ColorWhite

$OutputTitle.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    15
)

$OutputHeader.Controls.Add($OutputTitle)

# ============================================================
# BACK BUTTON
# ============================================================

$BackButton = New-Object System.Windows.Forms.Button

$BackButton.Text = "Back to Menu"

$BackButton.Width = 120

$BackButton.Height = 34

$BackButton.Location = New-Object System.Drawing.Point(
    850,
    13
)

$BackButton.FlatStyle = "Flat"

$BackButton.FlatAppearance.BorderSize = 0

$BackButton.BackColor = $ColorBlue

$BackButton.ForeColor = $ColorWhite

$BackButton.Font = New-Object System.Drawing.Font(
    "Segoe UI Semibold",
    9
)

$OutputHeader.Controls.Add($BackButton)

# ============================================================
# OUTPUT BOX
# ============================================================

$OutputBox = New-Object System.Windows.Forms.RichTextBox

$OutputBox.Dock = "Fill"

$OutputBox.ReadOnly = $true

$OutputBox.BackColor =
    [System.Drawing.Color]::FromArgb(
        15,23,42
    )

$OutputBox.ForeColor =
    [System.Drawing.Color]::FromArgb(
        226,232,240
    )

$OutputBox.BorderStyle = "None"

$OutputBox.Font = New-Object System.Drawing.Font(
    "Consolas",
    10
)

$OutputBox.ScrollBars = "Vertical"

$OutputPanel.Controls.Add($OutputBox)

$OutputBox.BringToFront()

# ============================================================
# STATUS LABEL
# ============================================================

$StatusLabel = New-Object System.Windows.Forms.Label

$StatusLabel.Text = "Loading scripts..."

$StatusLabel.Location = New-Object System.Drawing.Point(
    35,
    20
)

$StatusLabel.AutoSize = $true

$StatusLabel.ForeColor = $ColorSubText

$StatusLabel.Font = New-Object System.Drawing.Font(
    "Segoe UI",
    10
)

$ScriptListPanel.Controls.Add($StatusLabel)

# ============================================================
# ADD SCRIPT BUTTON
# ============================================================

function Add-ScriptButton {

    param(
        [Parameter(Mandatory)]
        $Script
    )

    $Button = New-Object System.Windows.Forms.Button

    $Button.Text = $Script.name

    $Button.Width = 900

    $Button.Height = 55

    $Button.Margin = New-Object System.Windows.Forms.Padding(
        0,
        0,
        0,
        10
    )

    $Button.FlatStyle = "Flat"

    $Button.FlatAppearance.BorderSize = 0

    $Button.BackColor = $ColorWhite

    $Button.ForeColor = $ColorText

    $Button.Font = New-Object System.Drawing.Font(
        "Segoe UI Semibold",
        11
    )

    $Button.TextAlign = "MiddleLeft"

    $Button.Padding = New-Object System.Windows.Forms.Padding(
        20,
        0,
        0,
        0
    )

    $Button.Cursor =
        [System.Windows.Forms.Cursors]::Hand

    $Button.Tag = $Script

    # --------------------------------------------------------
    # Hover
    # --------------------------------------------------------

    $Button.Add_MouseEnter({

        $this.BackColor =
            [System.Drawing.Color]::FromArgb(
                239,246,255
            )

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

        $SelectedScript = $this.Tag

        Start-Script `
            -ScriptName $SelectedScript.name
    })

    $ScriptListPanel.Controls.Add($Button)
}

# ============================================================
# SHOW MENU
# ============================================================

function Show-MainMenu {

    $OutputPanel.Visible = $false

    $ContentPanel.Visible = $true

    $ScriptListPanel.Controls.Clear()

    $StatusLabel = New-Object System.Windows.Forms.Label

    $StatusLabel.Text = "Retrieving scripts from GitHub..."

    $StatusLabel.AutoSize = $true

    $StatusLabel.ForeColor = $ColorSubText

    $StatusLabel.Font = New-Object System.Drawing.Font(
        "Segoe UI",
        10
    )

    $ScriptListPanel.Controls.Add($StatusLabel)

    try {

        $Scripts = Get-GitHubScripts

        $ScriptListPanel.Controls.Clear()

        if (!$Scripts -or $Scripts.Count -eq 0) {

            $NoScripts = New-Object System.Windows.Forms.Label

            $NoScripts.Text =
                "No PowerShell scripts were found."

            $NoScripts.AutoSize = $true

            $NoScripts.ForeColor = $ColorRed

            $NoScripts.Font = New-Object System.Drawing.Font(
                "Segoe UI",
                11
            )

            $ScriptListPanel.Controls.Add(
                $NoScripts
            )

            return
        }

        $HeaderLabel = New-Object System.Windows.Forms.Label

        $HeaderLabel.Text =
            "$($Scripts.Count) scripts available"

        $HeaderLabel.AutoSize = $true

        $HeaderLabel.Margin =
            New-Object System.Windows.Forms.Padding(
                0,
                0,
                0,
                15
            )

        $HeaderLabel.ForeColor = $ColorSubText

        $HeaderLabel.Font = New-Object System.Drawing.Font(
            "Segoe UI",
            10
        )

        $ScriptListPanel.Controls.Add(
            $HeaderLabel
        )

        foreach ($Script in $Scripts) {

            Add-ScriptButton `
                -Script $Script
        }

    }
    catch {

        $ScriptListPanel.Controls.Clear()

        $ErrorLabel = New-Object System.Windows.Forms.Label

        $ErrorLabel.Text =
            "Unable to retrieve scripts.`r`n`r`n$($_.Exception.Message)"

        $ErrorLabel.AutoSize = $true

        $ErrorLabel.MaximumSize =
            New-Object System.Drawing.Size(
                850,
                0
            )

        $ErrorLabel.ForeColor = $ColorRed

        $ErrorLabel.Font = New-Object System.Drawing.Font(
            "Segoe UI",
            10
        )

        $ScriptListPanel.Controls.Add(
            $ErrorLabel
        )
    }
}

# ============================================================
# RUN SCRIPT
# ============================================================

function Start-Script {

    param(
        [Parameter(Mandatory)]
        [string]$ScriptName
    )

    try {

        # ----------------------------------------------------
        # Download
        # ----------------------------------------------------

        $OutputPanel.Visible = $true

        $ContentPanel.Visible = $false

        $OutputTitle.Text =
            "Loading: $ScriptName"

        $OutputBox.Clear()

        $OutputBox.AppendText(
            "Downloading $ScriptName ...`r`n"
        )

        $OutputBox.Refresh()

        $LocalScript = Get-GitHubScript `
            -FileName $ScriptName

        $OutputBox.AppendText(
            "Downloaded successfully.`r`n"
        )

        $OutputBox.AppendText(
            "Location: $LocalScript`r`n`r`n"
        )

        $OutputBox.AppendText(
            "Starting script...`r`n"
        )

        $OutputBox.AppendText(
            "============================================================`r`n"
        )

        $OutputBox.Refresh()

        # ----------------------------------------------------
        # Create PowerShell process
        # ----------------------------------------------------

        $ProcessInfo =
            New-Object System.Diagnostics.ProcessStartInfo

        $ProcessInfo.FileName =
            "powershell.exe"

        $ProcessInfo.Arguments =
            "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$LocalScript`""

        $ProcessInfo.UseShellExecute = $false

        $ProcessInfo.CreateNoWindow = $true

        $ProcessInfo.RedirectStandardOutput = $true

        $ProcessInfo.RedirectStandardError = $true

        $ProcessInfo.WorkingDirectory =
            $TempFolder

        $Process =
            New-Object System.Diagnostics.Process

        $Process.StartInfo = $ProcessInfo

        # ----------------------------------------------------
        # Output events
        # ----------------------------------------------------

        $Process.add_OutputDataReceived({

            param($Sender,$Event)

            if ($Event.Data) {

                $Form.BeginInvoke(
                    [Action]{

                        $OutputBox.AppendText(
                            $Event.Data + "`r`n"
                        )

                        $OutputBox.SelectionStart =
                            $OutputBox.TextLength

                        $OutputBox.ScrollToCaret()
                    }
                )
            }
        })

        # ----------------------------------------------------
        # Error events
        # ----------------------------------------------------

        $Process.add_ErrorDataReceived({

            param($Sender,$Event)

            if ($Event.Data) {

                $Form.BeginInvoke(
                    [Action]{

                        $OutputBox.SelectionColor =
                            $ColorRed

                        $OutputBox.AppendText(
                            $Event.Data + "`r`n"
                        )

                        $OutputBox.SelectionColor =
                            $OutputBox.ForeColor

                        $OutputBox.SelectionStart =
                            $OutputBox.TextLength

                        $OutputBox.ScrollToCaret()
                    }
                )
            }
        })

        # ----------------------------------------------------
        # Start
        # ----------------------------------------------------

        [void]$Process.Start()

        $Process.BeginOutputReadLine()

        $Process.BeginErrorReadLine()

        # ----------------------------------------------------
        # Timer watches process
        # ----------------------------------------------------

        $Timer = New-Object System.Windows.Forms.Timer

        $Timer.Interval = 500

        $Timer.Add_Tick({

            if ($Process.HasExited) {

                $Timer.Stop()

                $ExitCode =
                    $Process.ExitCode

                $OutputBox.AppendText(
                    "`r`n============================================================`r`n"
                )

                if ($ExitCode -eq 0) {

                    $OutputBox.SelectionColor =
                        $ColorGreen

                    $OutputBox.AppendText(
                        "Script completed successfully. Exit Code: $ExitCode`r`n"
                    )

                }
                else {

                    $OutputBox.SelectionColor =
                        $ColorRed

                    $OutputBox.AppendText(
                        "Script finished with Exit Code: $ExitCode`r`n"
                    )
                }

                $OutputBox.SelectionColor =
                    $OutputBox.ForeColor

                $OutputBox.AppendText(
                    "============================================================`r`n"
                )

                $OutputBox.SelectionStart =
                    $OutputBox.TextLength

                $OutputBox.ScrollToCaret()

                $BackButton.Enabled = $true
            }
        })

        $BackButton.Enabled = $false

        $Timer.Start()

    }
    catch {

        $OutputBox.AppendText(
            "`r`nERROR:`r`n$($_.Exception.Message)`r`n"
        )

        $BackButton.Enabled = $true
    }
}

# ============================================================
# BACK TO MENU
# ============================================================

$BackButton.Add_Click({

    Show-MainMenu
})

# ============================================================
# REFRESH
# ============================================================

$RefreshButton.Add_Click({

    Show-MainMenu
})

# ============================================================
# FORM SHOWN
# ============================================================

$Form.Add_Shown({

    Show-MainMenu
})

# ============================================================
# CLEANUP TEMP FILES WHEN FORM CLOSES
# ============================================================

$Form.Add_FormClosing({

    try {

        if (Test-Path $TempFolder) {

            Remove-Item `
                $TempFolder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

    }
    catch {
    }
})

# ============================================================
# START APPLICATION
# ============================================================

[void]$Form.ShowDialog()
