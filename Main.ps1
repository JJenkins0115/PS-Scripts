# ============================================================
# ADMIN TOOLKIT - MAIN MENU & EMBEDDED CONSOLE
# ============================================================

[CmdletBinding()]
param()

# ============================================================
# CONFIGURATION
# ============================================================

$GitHubUser   = "JJenkins0115"
$GitHubRepo   = "PS-Scripts"
$GitHubBranch = "main"

# Name displayed in the application
$ToolkitName = "Admin Toolkit"

# Temporary download location
$TempFolder = Join-Path -Path $env:TEMP -ChildPath "AdminToolkit"

# Main script name - this will NOT be shown as a tool
$MainScriptName = "Main.ps1"

# # ============================================================
# # HIDE POWERSHELL CONSOLE
# # ============================================================

# # Check if the type is already compiled in the current AppDomain
# # to prevent 'Type name ConsoleWindow already exists' errors in VS Code/ISE.
# if (-not ([System.Management.Automation.PSTypeName]'ConsoleWindow').Type) {
#     Add-Type -TypeDefinition @"
# using System;
# using System.Runtime.InteropServices;

# public class ConsoleWindow {
#     [DllImport("kernel32.dll")]
#     public static extern IntPtr GetConsoleWindow();

#     [DllImport("user32.dll")]
#     public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
# }
# "@
# }

# # Retrieve console handle and hide window if running interactively
# $ConsoleHandle = [ConsoleWindow]::GetConsoleWindow()

# if ($ConsoleHandle -ne [IntPtr]::Zero) {
#     # 0 = SW_HIDE
#     [ConsoleWindow]::ShowWindow($ConsoleHandle, 0)
# }
# ============================================================
# LOAD WINDOWS FORMS & DRAWING
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = "Stop"

# ============================================================
# COLOR PALETTE
# ============================================================

$ColorBackground = [System.Drawing.Color]::FromArgb(245, 247, 250)
$ColorHeader     = [System.Drawing.Color]::FromArgb(30, 41, 59)
$ColorBlue       = [System.Drawing.Color]::FromArgb(37, 99, 235)
$ColorText       = [System.Drawing.Color]::FromArgb(30, 41, 59)
$ColorSubText    = [System.Drawing.Color]::FromArgb(100, 116, 139)
$ColorWhite      = [System.Drawing.Color]::White

# Console Terminal Palette
$ColorConsoleBg  = [System.Drawing.Color]::FromArgb(15, 23, 42)
$ColorConsoleFg  = [System.Drawing.Color]::FromArgb(226, 232, 240)
$ColorErrorFg    = [System.Drawing.Color]::FromArgb(248, 113, 113)
$ColorWarningFg  = [System.Drawing.Color]::FromArgb(251, 191, 36)
$ColorInfoFg     = [System.Drawing.Color]::FromArgb(96, 165, 250)

# ============================================================
# GITHUB ENDPOINTS
# ============================================================

$GitHubAPI = "https://api.github.com/repos/$GitHubUser/$GitHubRepo/git/trees/$GitHubBranch`?recursive=1"
$RawBase   = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/refs/heads/$GitHubBranch"

# ============================================================
# INITIALIZE TEMP DIRECTORY
# ============================================================

if (-not (Test-Path -Path $TempFolder)) {
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-ConsoleOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [System.Drawing.Color]$Color = $ColorConsoleFg
    )

    if ($null -eq $global:ConsoleOutput -or $global:ConsoleOutput.IsDisposed) {
        return
    }

    $Action = [Action]{
        $global:ConsoleOutput.SelectionStart = $global:ConsoleOutput.TextLength
        $global:ConsoleOutput.SelectionLength = 0
        $global:ConsoleOutput.SelectionColor = $Color
        $global:ConsoleOutput.AppendText("$Text`r`n")
        $global:ConsoleOutput.ScrollToCaret()
    }

    if ($global:ConsoleOutput.InvokeRequired) {
        $global:ConsoleOutput.Invoke($Action) | Out-Null
    }
    else {
        $Action.Invoke()
    }
}

function Get-GitHubScripts {
    [CmdletBinding()]
    param()

    try {
        $Headers = @{
            "User-Agent" = "AdminToolkit"
            "Accept"     = "application/vnd.github+json"
        }

        $RepositoryTree = Invoke-RestMethod -Uri $GitHubAPI -Headers $Headers -Method Get -ErrorAction Stop

        if ($null -eq $RepositoryTree.tree) {
            throw "GitHub returned no repository files."
        }

        $Scripts = @()

        foreach ($Item in @($RepositoryTree.tree)) {
            if ($Item.type -ne "blob") { continue }
            if ($Item.path -notlike "*.ps1") { continue }
            if ($Item.path.Equals($MainScriptName, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

            $Parts = $Item.path -split "/"
            if ($Parts.Count -lt 2) { continue }

            $Folder       = $Parts[0]
            $FileName     = $Parts[-1]
            $RelativePath = $Item.path
            $RawURL       = "$RawBase/$RelativePath"

            $Scripts += [PSCustomObject]@{
                Name     = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
                FileName = $FileName
                Folder   = $Folder
                Path     = $RelativePath
                URL      = $RawURL
                SHA      = $Item.sha
            }
        }

        return @($Scripts | Sort-Object Folder, Name)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to retrieve scripts from GitHub.`r`n`r`n" +
            "Repository: $GitHubUser/$GitHubRepo`r`n" +
            "Branch: $GitHubBranch`r`n`r`n" +
            "Error: $($_.Exception.Message)",
            "GitHub Error",
            "OK",
            "Error"
        ) | Out-Null

        return @()
    }
}

function Get-RemoteScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )

    $LocalFile = Join-Path -Path $TempFolder -ChildPath $Script.FileName

    try {
        $Headers = @{ "User-Agent" = "AdminToolkit" }

        Invoke-WebRequest `
            -Uri $Script.URL `
            -Headers $Headers `
            -UseBasicParsing `
            -OutFile $LocalFile `
            -ErrorAction Stop

        if (-not (Test-Path -Path $LocalFile)) {
            throw "The script file could not be saved locally."
        }

        return $LocalFile
    }
    catch {
        Write-ConsoleOutput -Text "[-] Failed to download script: $($_.Exception.Message)" -Color $ColorErrorFg
        return $null
    }
}

function Start-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )

    Write-ConsoleOutput -Text "`r`n[>] Downloading script '$($Script.Name)'..." -Color $ColorInfoFg
    $LocalFile = Get-RemoteScript -Script $Script

    if (-not $LocalFile) { return }

    Write-ConsoleOutput -Text "[+] Executing: $LocalFile" -Color $ColorInfoFg
    Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText

    # Execute script asynchronously to prevent UI freeze
    [System.Threading.Tasks.Task]::Run([Action]{
        try {
            $PowerShell = [PowerShell]::Create()
            [void]$PowerShell.AddScript((Get-Content -Path $LocalFile -Raw))

            # Redirect Standard Output
            $PowerShell.Streams.Output.add_DataAdded({
                param($sender, $e)
                $Data = $sender[$e.Index]
                Write-ConsoleOutput -Text "$Data" -Color $ColorConsoleFg
            })

            # Redirect Error Output
            $PowerShell.Streams.Error.add_DataAdded({
                param($sender, $e)
                $Data = $sender[$e.Index]
                Write-ConsoleOutput -Text "[ERROR] $Data" -Color $ColorErrorFg
            })

            # Redirect Warning Output
            $PowerShell.Streams.Warning.add_DataAdded({
                param($sender, $e)
                $Data = $sender[$e.Index]
                Write-ConsoleOutput -Text "[WARN] $Data" -Color $ColorWarningFg
            })

            # Execute Script
            [void]$PowerShell.Invoke()
            $PowerShell.Dispose()

            Write-ConsoleOutput -Text "------------------------------------------------------------" -Color $ColorSubText
            Write-ConsoleOutput -Text "[+] Execution completed successfully." -Color $ColorInfoFg
        }
        catch {
            Write-ConsoleOutput -Text "[-] Execution Exception: $($_.Exception.Message)" -Color $ColorErrorFg
        }
    }) | Out-Null
}

function Execute-CustomCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText
    )

    if ([string]::IsNullOrWhiteSpace($CommandText)) { return }

    Write-ConsoleOutput -Text "`r`nPS> $CommandText" -Color $ColorInfoFg

    [System.Threading.Tasks.Task]::Run([Action]{
        try {
            $PowerShell = [PowerShell]::Create()
            [void]$PowerShell.AddScript($CommandText)

            $Results = $PowerShell.Invoke()

            foreach ($Item in $Results) {
                Write-ConsoleOutput -Text "$Item" -Color $ColorConsoleFg
            }

            foreach ($Err in $PowerShell.Streams.Error) {
                Write-ConsoleOutput -Text "[ERROR] $Err" -Color $ColorErrorFg
            }

            $PowerShell.Dispose()
        }
        catch {
            Write-ConsoleOutput -Text "[-] Command Exception: $($_.Exception.Message)" -Color $ColorErrorFg
        }
    }) | Out-Null
}

# ============================================================
# UI BUILDER FUNCTIONS
# ============================================================

function New-ScriptButton {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )

    $Button = New-Object System.Windows.Forms.Button
    $Button.Width = 280
    $Button.Height = 40
    $Button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $Button.Text = "  >  $($Script.Name)"
    $Button.TextAlign = "MiddleLeft"
    $Button.FlatStyle = "Flat"
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $ColorWhite
    $Button.ForeColor = $ColorText
    $Button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Button.Tag = $Script

    $Button.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(239, 246, 255) })
    $Button.Add_MouseLeave({ $this.BackColor = $ColorWhite })
    $Button.Add_Click({ Start-Tool -Script $this.Tag })

    return $Button
}

function New-FolderHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )

    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = $FolderName.ToUpper()
    $Label.Width = 280
    $Label.Height = 30
    $Label.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 4)
    $Label.ForeColor = $ColorSubText
    $Label.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)

    return $Label
}

# ============================================================
# MAIN WINDOW FORM DEFINITION
# ============================================================

$Form = New-Object System.Windows.Forms.Form
$Form.Text = $ToolkitName
$Form.Size = New-Object System.Drawing.Size(1100, 750)
$Form.MinimumSize = New-Object System.Drawing.Size(900, 600)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = $ColorBackground

# ============================================================
# HEADER PANEL
# ============================================================

$Header = New-Object System.Windows.Forms.Panel
$Header.Dock = "Top"
$Header.Height = 80
$Header.BackColor = $ColorHeader
$Form.Controls.Add($Header)

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = $ToolkitName
$TitleLabel.Location = New-Object System.Drawing.Point(25, 15)
$TitleLabel.AutoSize = $true
$TitleLabel.ForeColor = $ColorWhite
$TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$Header.Controls.Add($TitleLabel)

$SubtitleLabel = New-Object System.Windows.Forms.Label
$SubtitleLabel.Text = "Select a tool from the menu to execute in the embedded console"
$SubtitleLabel.Location = New-Object System.Drawing.Point(27, 48)
$SubtitleLabel.AutoSize = $true
$SubtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$SubtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$Header.Controls.Add($SubtitleLabel)

$RefreshButton = New-Object System.Windows.Forms.Button
$RefreshButton.Text = "Refresh"
$RefreshButton.Width = 90
$RefreshButton.Height = 32
$RefreshButton.Location = New-Object System.Drawing.Point(960, 24)
$RefreshButton.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$RefreshButton.FlatStyle = "Flat"
$RefreshButton.FlatAppearance.BorderSize = 0
$RefreshButton.BackColor = $ColorBlue
$RefreshButton.ForeColor = $ColorWhite
$RefreshButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$Header.Controls.Add($RefreshButton)

# ============================================================
# MAIN SPLIT CONTAINER (LEFT MENU / RIGHT CONSOLE)
# ============================================================

$SplitContainer = New-Object System.Windows.Forms.SplitContainer
$SplitContainer.Dock = "Fill"
$SplitContainer.SplitterDistance = 310
$SplitContainer.IsSplitterFixed = $false
$SplitContainer.BackColor = $ColorBackground
$Form.Controls.Add($SplitContainer)

# Left Side Panel - Script Menu
$ScrollPanel = New-Object System.Windows.Forms.Panel
$ScrollPanel.Dock = "Fill"
$ScrollPanel.AutoScroll = $true
$ScrollPanel.Padding = New-Object System.Windows.Forms.Padding(15)
$SplitContainer.Panel1.Controls.Add($ScrollPanel)

$ScriptPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$ScriptPanel.FlowDirection = "TopDown"
$ScriptPanel.WrapContents = $false
$ScriptPanel.AutoSize = $true
$ScriptPanel.AutoSizeMode = "GrowAndShrink"
$ScriptPanel.Dock = "Top"
$ScrollPanel.Controls.Add($ScriptPanel)

# Right Side Panel - Console Container
$ConsoleContainer = New-Object System.Windows.Forms.Panel
$ConsoleContainer.Dock = "Fill"
$ConsoleContainer.Padding = New-Object System.Windows.Forms.Padding(10)
$ConsoleContainer.BackColor = $ColorBackground
$SplitContainer.Panel2.Controls.Add($ConsoleContainer)

# Console Output Box
$global:ConsoleOutput = New-Object System.Windows.Forms.RichTextBox
$global:ConsoleOutput.Dock = "Fill"
$global:ConsoleOutput.BackColor = $ColorConsoleBg
$global:ConsoleOutput.ForeColor = $ColorConsoleFg
$global:ConsoleOutput.Font = New-Object System.Drawing.Font("Consolas", 10)
$global:ConsoleOutput.ReadOnly = $true
$global:ConsoleOutput.BorderStyle = "None"
$global:ConsoleOutput.Text = "============================================================`r`n Admin Toolkit Console initialized.`r`n Select a script from the menu to execute output here.`r`n============================================================`r`n"
$ConsoleContainer.Controls.Add($global:ConsoleOutput)

# Console Input Panel (Bottom Control Bar)
$InputPanel = New-Object System.Windows.Forms.Panel
$InputPanel.Dock = "Bottom"
$InputPanel.Height = 40
$InputPanel.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)
$ConsoleContainer.Controls.Add($InputPanel)

$CommandInput = New-Object System.Windows.Forms.TextBox
$CommandInput.Dock = "Fill"
$CommandInput.BackColor = $ColorConsoleBg
$CommandInput.ForeColor = $ColorConsoleFg
$CommandInput.Font = New-Object System.Drawing.Font("Consolas", 10)
$CommandInput.BorderStyle = "FixedSingle"
$InputPanel.Controls.Add($CommandInput)

$SendButton = New-Object System.Windows.Forms.Button
$SendButton.Text = "Run"
$SendButton.Dock = "Right"
$SendButton.Width = 60
$SendButton.FlatStyle = "Flat"
$SendButton.FlatAppearance.BorderSize = 0
$SendButton.BackColor = $ColorBlue
$SendButton.ForeColor = $ColorWhite
$SendButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
$InputPanel.Controls.Add($SendButton)

# Command Input Event Handling
$ExecuteInput = {
    $Command = $CommandInput.Text
    $CommandInput.Clear()
    Execute-CustomCommand -CommandText $Command
}

$SendButton.Add_Click($ExecuteInput)
$CommandInput.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $_.SuppressKeyPress = $true
        $ExecuteInput.Invoke()
    }
})

# ============================================================
# LOAD SCRIPTS LOGIC
# ============================================================

function Load-Scripts {
    $RefreshButton.Enabled = $false
    $RefreshButton.Text = "Loading..."
    $ScriptPanel.SuspendLayout()

    try {
        $ScriptPanel.Controls.Clear()
        $Scripts = Get-GitHubScripts

        if ($null -eq $Scripts -or $Scripts.Count -eq 0) {
            $NoScripts = New-Object System.Windows.Forms.Label
            $NoScripts.Text = "No PowerShell scripts were found.`r`n`r`nRepo: $GitHubUser/$GitHubRepo`r`nBranch: $GitHubBranch"
            $NoScripts.Width = 280
            $NoScripts.Height = 150
            $NoScripts.ForeColor = $ColorText
            $NoScripts.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
            $ScriptPanel.Controls.Add($NoScripts)
            return
        }

        $Groups = $Scripts | Group-Object Folder

        foreach ($Group in $Groups) {
            $FolderHeader = New-FolderHeader -FolderName $Group.Name
            $ScriptPanel.Controls.Add($FolderHeader)

            foreach ($Script in $Group.Group) {
                $Button = New-ScriptButton -Script $Script
                $ScriptPanel.Controls.Add($Button)
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to load scripts.`r`n`r`n$($_.Exception.Message)",
            "Admin Toolkit",
            "OK",
            "Error"
        ) | Out-Null
    }
    finally {
        $ScriptPanel.ResumeLayout()
        $RefreshButton.Enabled = $true
        $RefreshButton.Text = "Refresh"
    }
}

# ============================================================
# BINDINGS AND APPLICATION START
# ============================================================

$RefreshButton.Add_Click({ Load-Scripts })
$Form.Add_Shown({ Load-Scripts })

[void]$Form.ShowDialog()

# ============================================================
# CLEANUP
# ============================================================

try {
    if (Test-Path -Path $TempFolder) {
        Remove-Item -Path $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    # Suppress cleanup exceptions during teardown
}
