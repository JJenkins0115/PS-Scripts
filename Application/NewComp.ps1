function Start-SystemUpdates {
    $ModuleName = "PSWindowsUpdate"
    
    try {
        # 1. Force NuGet Provider installation
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

        # 2. Set PSGallery to Trusted
        if (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue) {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        # 3. Install the Module
        if (-not (Get-Module -ListAvailable $ModuleName)) {
            Install-Module $ModuleName -Force -Confirm:$false -Scope AllUsers -AllowClobber -ErrorAction Stop | Out-Null
        }
        
        # 4. Import and Execute Updates
        Import-Module $ModuleName -ErrorAction Stop
        Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -MicrosoftUpdate -ErrorAction SilentlyContinue
    } catch { 
        Write-Error "Update process encountered an error: $($_.Exception.Message)"
    }
}

function Add-ToDomain {
    param (
        [string]$Domain = "unit40.org",
        [string]$Username = "Techteam"
    )

    # Prompt user for password securely
    $Password = Read-Host -Prompt "Enter domain password for $Username" -AsSecureString
    $Credential = New-Object System.Management.Automation.PSCredential ("$Domain\$Username", $Password)

    # Join the domain and restart the computer
    Add-Computer -DomainName $Domain -Credential $Credential -Restart -Force
}

# --- Script Execution ---

# 1. Run all updates first
Start-SystemUpdates

# 2. Add to domain and reboot
Add-ToDomain
