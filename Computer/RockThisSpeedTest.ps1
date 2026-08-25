# =========================
# Speedtest CLI - Temp Run
# =========================

# ------------------------------------
# Function to run the test and format output
# ------------------------------------
function Get-InternetSpeed {
    param(
        [string]$SpeedtestPath
    )

    if (-not (Test-Path $SpeedtestPath)) {
        Write-Error "Speedtest CLI not found at $SpeedtestPath"
        return
    }

    Write-Host "`nRunning speed test..." -ForegroundColor Yellow

    $rawJson = & $SpeedtestPath --accept-license --accept-gdpr --format=json 2>&1
    try {
        $result = $rawJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Error "Failed to parse speedtest output. Raw output:`n$rawJson"
        return
    }

    # Get active network adapters
    $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
        Select-Object Name, InterfaceDescription, Status, LinkSpeed

    # Build clean output object
    $output = [PSCustomObject]@{
        "Timestamp"           = $result.timestamp
        "Public IP"           = $result.interface.externalIp
        "ISP"                 = $result.isp
        "Ping (ms)"           = [math]::Round($result.ping.latency, 2)
        "Jitter (ms)"         = [math]::Round($result.ping.jitter, 2)
        "Packet Loss (%)"     = if ($null -ne $result.packetLoss) { $result.packetLoss } else { "N/A" }
        "Download (Mbps)"     = [math]::Round($result.download.bandwidth * 8 / 1MB, 2)
        "Upload (Mbps)"       = [math]::Round($result.upload.bandwidth * 8 / 1MB, 2)
        "Server"              = $result.server.name
        "Server Location"     = "$($result.server.location), $($result.server.country)"
        "Result URL"          = $result.result.url
    }

    Write-Host "`n===== Internet Speed Test Results =====" -ForegroundColor Cyan
    $output | Format-List

    Write-Host "`n===== Active Network Adapters =====" -ForegroundColor Cyan
    $activeAdapters | Format-Table -AutoSize

    # Optional CSV logging
    if ($EnableLogging) {
        $output | Export-Csv -Path $LogPath -Append -NoTypeInformation
        Write-Host "Results logged to $LogPath" -ForegroundColor DarkGray
    }
}

# ------------------------------------
# Configuration
# ------------------------------------

# Version config - update this string to upgrade the CLI
$SpeedtestVersion = "1.2.0-win64"
$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-$SpeedtestVersion.zip"

# Optional: set to $true to log results to a CSV file
$EnableLogging = $false
$LogPath = "$env:USERPROFILE\SpeedtestLog.csv"

# ------------------------------------
# Main execution
# ------------------------------------

# Create a unique temp directory
$TempDir = Join-Path -Path $env:TEMP -ChildPath ("SpeedtestCLI_" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Paths for zip and extracted exe
$ZipPath = Join-Path $TempDir "speedtest.zip"
$ExtractPath = $TempDir

try {
    # Download the zip
    Write-Host "Downloading Speedtest CLI..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error "Download failed: $_"
        exit 1
    }

    # Extract zip
    Write-Host "Extracting files..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop
    } catch {
        Write-Error "Extraction failed: $_"
        exit 1
    }

    # Find the speedtest.exe
    $speedtestExe = Get-ChildItem -Path $ExtractPath -Filter "speedtest.exe" -Recurse | Select-Object -First 1

    if (-not $speedtestExe) {
        Write-Error "Failed to locate speedtest.exe after extraction."
        exit 1
    }

    # Run the speed test
    Get-InternetSpeed -SpeedtestPath $speedtestExe.FullName

} finally {
    # Cleanup AFTER output is shown
    Write-Host "`nCleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Done. Temporary files removed." -ForegroundColor Green

    # Keep window open so user can review (works in all host environments)
    Write-Host "`nPress Enter to close this window..." -ForegroundColor DarkGray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Read-Host
    }
}
