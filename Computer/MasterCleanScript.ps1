 Write-host "Starting Driver Store and System Maintenance Tasks..." "INFO"
    
    # Configure GitHub release asset parameters inside temporary workspace
    $downloadUrl = "https://github.com/lostindark/DriverStoreExplorer/releases/download/v0.12.64/DriverStoreExplorer.v0.12.64.zip"
    $extractPath = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer"
    $zipPath     = Join-Path -Path $env:TEMP -ChildPath "U40Tech\DriverStoreExplorer.zip"
    
    $driverProcess = $null

    try {
        if (-not (Test-Path $extractPath)) { 
            New-Item $extractPath -ItemType Directory -Force | Out-Null 
        }

        Write-host "Downloading DriverStoreExplorer from GitHub..." "INFO"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        
        Write-host "Extracting DriverStoreExplorer package..." "INFO"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        
        # Locate Rapr.exe regardless of folder depth inside the zip
        $exeFile = Get-ChildItem -Path $extractPath -Recurse -Filter "Rapr.exe" | Select-Object -First 1

        if ($exeFile) {
            Write-host "Launching DriverStoreExplorer background process (/purge)..." "INFO"
            $driverProcess = Start-Process -FilePath $exeFile.FullName -ArgumentList "/purge" -Verb RunAs -PassThru
        } else {
            Write-host "Rapr.exe not found inside extracted package." "ERROR"
        }

        # Orphaned MSI/MSP Registry Check
        Write-host "Scanning for orphaned MSI/MSP files..." "INFO"
        $InstallerPath = "C:\Windows\Installer"
        if (Test-Path $InstallerPath) {
            $AllFiles = Get-ChildItem -Path $InstallerPath -Include *.msi, *.msp -Recurse -ErrorAction SilentlyContinue
            foreach ($File in $AllFiles) {
                $Match = Get-CimInstance -Query "SELECT LocalPackage FROM Win32_Product WHERE LocalPackage = '$($File.FullName -replace '\\','\\')'" -ErrorAction SilentlyContinue
                if (-not $Match) {
                    try { 
                        Remove-Item $File.FullName -Force -ErrorAction Stop
                        Write-host "Deleted orphaned file: $($File.Name)" "SUCCESS"
                    } catch { }
                }
            }
        }

        if ($null -ne $driverProcess -and -not $driverProcess.HasExited) {
            Write-host "Waiting for DriverStoreExplorer task completion..." "INFO"
            $driverProcess | Wait-Process
            Write-host "Driver cleanup complete." "SUCCESS"
        }
    } 
    finally {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
    }    
}
