# Optimized for Visual Studio Code Terminal
# Ensure you run as Administrator for full C: access
# Computer/CheckStorage.ps1
Set-StrictMode -Version Latest

function Get-DiskUsageSummary {
    [CmdletBinding()]
    param()

    process {
        Write-Host "--- DRIVE C: CAPACITY ---" -ForegroundColor Cyan
        $drive = Get-PSDrive C | Select-Object Used, Free, @{Name="Total"; Expression={$_.Used + $_.Free}}
        
        [PSCustomObject]@{
            "Total (GB)" = [Math]::Round($drive.Total / 1GB, 2)
            "Used (GB)"  = [Math]::Round($drive.Used / 1GB, 2)
            "Free (GB)"  = [Math]::Round($drive.Free / 1GB, 2)
            "Usage (%)"  = [Math]::Round(($drive.Used / $drive.Total) * 100, 2)
        } | Format-Table -AutoSize

        Write-Host "`n--- SCANNING FILE SYSTEM (This may take a moment) ---" -ForegroundColor Yellow
        
        # Gathering all files once to save I/O cycles
        $allFiles = Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue

        Write-Host "--- TOP 50 LARGEST FILES ---" -ForegroundColor Cyan
        if ($null -ne $allFiles) {
            $allFiles | Sort-Object Length -Descending | Select-Object -First 50 | 
                Select-Object @{Name="FileName"; Expression={$_.Name}}, 
                              @{Name="Size (MB)"; Expression={[Math]::Round($_.Length / 1MB, 2)}}, 
                              DirectoryName | 
                Format-Table -AutoSize
        }

        Write-Host "`n--- TOP 5 LARGEST ROOT DIRECTORIES ---" -ForegroundColor Cyan
        $rootDirs = Get-ChildItem -Path "C:\" -Directory -ErrorAction SilentlyContinue
        
        $folderReport = foreach ($dir in $rootDirs) {
            # Fix: Capture the measurement object first to avoid StrictMode property errors
            $measure = Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                       Measure-Object -Property Length -Sum
            
            # Why: If a folder is empty or inaccessible, .Sum won't exist. 
            # We check if it's null and default to 0.
            $totalSize = 0
            if ($null -ne $measure -and $null -ne $measure.Sum) {
                $totalSize = $measure.Sum
            }

            [PSCustomObject]@{
                FolderName = $dir.Name
                "Size (GB)" = [Math]::Round(($totalSize / 1GB), 2)
            }
        }

        if ($null -ne $folderReport) {
            $folderReport | Sort-Object "Size (GB)" -Descending | Select-Object -First 5 | Format-Table -AutoSize
        }
    }
}

Get-DiskUsageSummary
