# ============================================
# PowerShell Tools - GUI Console
# Checkbox multi-select + queued execution + dependency auto-install
# ============================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$GitHubUser = "JJenkins0115"
$Repository = "PS-Scripts"
$Branch = "main"
$RawBase    = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch"
$ApiUrl     = "https://api.github.com/repos/$GitHubUser/$Repository/contents"

# ------------------------------------------------
# Dependency scanning / installation
# ------------------------------------------------
function Get-ScriptRequirements {
    param([string]$Content)

    $Result = [PSCustomObject]@{
        Modules    = @()
        MinVersion = $null
        NeedsAdmin = $false
    }

    # #Requires -Modules Foo,Bar   or   #Requires -Module Foo
    foreach ($m in [regex]::Matches($Content, '(?im)^\s*#Requires\s+-Modules?\s+(.+)$')) {
        $names = $m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") }
        $Result.Modules += $names
    }

    # Fallback: plain Import-Module calls the script author didn't declare via #Requires
    foreach ($m in [regex]::Matches($Content, '(?im)^\s*Import-Module\s+([A-Za-z0-9_.\-]+)')) {
        $Result.Modules += $m.Groups[1].Value
    }

    $Result.Modules = $Result.Modules | Sort-Object -Unique

    $verMatch = [regex]::Match($Content, '(?im)^\s*#Requires\s+-Version\s+([\d.]+)')
    if ($verMatch.Success) { $Result.MinVersion = [version]$verMatch.Groups[1].Value }

    if ($Content -match '(?im)^\s*#Requires\s+-RunAsAdministrator') {
        $Result.NeedsAdmin = $true
    }

    return $Result
}

function Ensure-PSGalleryReady {
    param([scriptblock]$Log)

    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        & $Log "Installing NuGet provider (required to install modules)..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }

    $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($gallery -and $gallery.InstallationPolicy -ne 'Trusted') {
        & $Log "Trusting PSGallery repository..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

function Resolve-ScriptDependencies {
    param(
        [string]$Content,
        [scriptblock]$Log
    )

    $Req = Get-ScriptRequirements -Content $Content

    if ($Req.MinVersion -and $PSVersionTable.PSVersion -lt $Req.MinVersion) {
        & $Log "WARNING: script requires PowerShell $($Req.MinVersion)+ (you have $($PSVersionTable.PSVersion)). Cannot auto-upgrade PowerShell; the script may fail."
    }

    if ($Req.NeedsAdmin) {
        & $Log "Note: script declares it needs to run as Administrator (it will be launched elevated)."
    }

    if ($Req.Modules.Count -gt 0) {
        Ensure-PSGalleryReady -Log $Log
    }

    foreach ($mod in $Req.Modules) {
        if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
            & $Log "Module '$mod' already installed."
            continue
        }
        & $Log "Module '$mod' is missing - installing..."
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            & $Log "Installed '$mod'."
        }
        catch {
            & $Log "ERROR: could not install '$mod' - $($_.Exception.Message)"
        }
    }

    if ($Req.Modules.Count -eq 0 -and -not $Req.MinVersion -and -not $Req.NeedsAdmin) {
        & $Log "No declared requirements found (nothing to install)."
    }
}

# ------------------------------------------------
# GUI
# ------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "PowerShell Tools Console"
$Form.Size = New-Object System.Drawing.Size(560, 640)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = 'FixedDialog'
$Form.MaximizeBox = $false

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Select scripts to queue:"
$Label.Location = New-Object System.Drawing.Point(15, 15)
$Label.AutoSize = $true
$Form.Controls.Add($Label)

$CheckedList = New-Object System.Windows.Forms.CheckedListBox
$CheckedList.Location = New-Object System.Drawing.Point(15, 40)
$CheckedList.Size = New-Object System.Drawing.Size(510, 220)
$CheckedList.CheckOnClick = $true
$Form.Controls.Add($CheckedList)

$RefreshBtn = New-Object System.Windows.Forms.Button
$RefreshBtn.Text = "Refresh List"
$RefreshBtn.Location = New-Object System.Drawing.Point(15, 270)
$RefreshBtn.Size = New-Object System.Drawing.Size(115, 30)
$Form.Controls.Add($RefreshBtn)

$SelectAllBtn = New-Object System.Windows.Forms.Button
$SelectAllBtn.Text = "Select All"
$SelectAllBtn.Location = New-Object System.Drawing.Point(140, 270)
$SelectAllBtn.Size = New-Object System.Drawing.Size(90, 30)
$Form.Controls.Add($SelectAllBtn)

$ClearBtn = New-Object System.Windows.Forms.Button
$ClearBtn.Text = "Clear"
$ClearBtn.Location = New-Object System.Drawing.Point(240, 270)
$ClearBtn.Size = New-Object System.Drawing.Size(90, 30)
$Form.Controls.Add($ClearBtn)

$RunBtn = New-Object System.Windows.Forms.Button
$RunBtn.Text = "Run Queue"
$RunBtn.Location = New-Object System.Drawing.Point(345, 270)
$RunBtn.Size = New-Object System.Drawing.Size(180, 30)
$RunBtn.BackColor = [System.Drawing.Color]::LightGreen
$Form.Controls.Add($RunBtn)

$LogLabel = New-Object System.Windows.Forms.Label
$LogLabel.Text = "Log:"
$LogLabel.Location = New-Object System.Drawing.Point(15, 310)
$LogLabel.AutoSize = $true
$Form.Controls.Add($LogLabel)

$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Location = New-Object System.Drawing.Point(15, 335)
$LogBox.Size = New-Object System.Drawing.Size(510, 240)
$LogBox.Multiline = $true
$LogBox.ScrollBars = "Vertical"
$LogBox.ReadOnly = $true
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$Form.Controls.Add($LogBox)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready."
$StatusLabel.Location = New-Object System.Drawing.Point(15, 585)
$StatusLabel.AutoSize = $true
$Form.Controls.Add($StatusLabel)

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    $LogBox.AppendText("$line`r`n")
    [System.Windows.Forms.Application]::DoEvents()
}

$Global:ScriptObjects = @()

function Load-ScriptList {
    $CheckedList.Items.Clear()
    $StatusLabel.Text = "Fetching script list..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $Files = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        $Global:ScriptObjects = @(
            $Files | Where-Object {
                $_.type -eq "file" -and $_.name -like "*.ps1" -and $_.name -ne "Main.ps1" -and $_.name -ne "Main-GUI.ps1"
            } | Sort-Object name
        )
        foreach ($s in $Global:ScriptObjects) {
            $CheckedList.Items.Add($s.name) | Out-Null
        }
        $StatusLabel.Text = "Loaded $($Global:ScriptObjects.Count) script(s)."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Unable to retrieve scripts: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
        $StatusLabel.Text = "Failed to load scripts."
    }
}

$RefreshBtn.Add_Click({ Load-ScriptList })

$SelectAllBtn.Add_Click({
    for ($i = 0; $i -lt $CheckedList.Items.Count; $i++) { $CheckedList.SetItemChecked($i, $true) }
})

$ClearBtn.Add_Click({
    for ($i = 0; $i -lt $CheckedList.Items.Count; $i++) { $CheckedList.SetItemChecked($i, $false) }
})

$RunBtn.Add_Click({
    $selectedNames = $CheckedList.CheckedItems | ForEach-Object { $_.ToString() }
    if ($selectedNames.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Select at least one script first.", "Nothing selected", "OK", "Warning") | Out-Null
        return
    }

    $Queue = foreach ($n in $selectedNames) {
        $Global:ScriptObjects | Where-Object { $_.name -eq $n }
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Run $($Queue.Count) script(s) in order? Each will download, have its dependencies checked/installed, then run elevated. The queue waits for each one to close before starting the next.",
        "Confirm queue",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $RunBtn.Enabled = $false
    $RefreshBtn.Enabled = $false
    $StatusLabel.Text = "Running queue..."
    $LogBox.Clear()

    foreach ($item in $Queue) {
        Write-Log "==== $($item.name) ===="

        $ScriptUrl = "$RawBase/$($item.name)"
        $TempFile  = Join-Path $env:TEMP $item.name

        Write-Log "Downloading..."
        try {
            Invoke-WebRequest -Uri $ScriptUrl -OutFile $TempFile -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Log "ERROR downloading: $($_.Exception.Message) - skipping this script."
            continue
        }

        $Content = Get-Content -Path $TempFile -Raw
        Write-Log "Checking required modules / PowerShell version..."
        Resolve-ScriptDependencies -Content $Content -Log { param($m) Write-Log $m }

        Write-Log "Launching elevated, waiting for it to close..."
        try {
            Start-Process powershell.exe `
                -Verb RunAs `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TempFile`"" `
                -Wait
            Write-Log "Finished $($item.name)."
        }
        catch {
            Write-Log "ERROR launching: $($_.Exception.Message)"
        }
    }

    Write-Log "Queue complete."
    $StatusLabel.Text = "Queue complete. Ready."
    $RunBtn.Enabled = $true
    $RefreshBtn.Enabled = $true
})

Load-ScriptList
[void]$Form.ShowDialog()
