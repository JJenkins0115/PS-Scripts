   Write-Host "Checking for Windows Updates (Zero-Prompt Mode)..." "INFO"
    $ModuleName = "PSWindowsUpdate"
    
    try {
        # 1. Force NuGet Provider installation (The "Do you want to install NuGet?" prompt)
        Write-host "Configuring NuGet Provider..." "INFO"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

        # 2. Set PSGallery to Trusted (The "Untrusted Repository" prompt)
        # This is the most common reason scripts hang waiting for a 'Y'
        if (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue) {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        # 3. Install the Module with -AllowClobber and -Force
        if (-not (Get-Module -ListAvailable $ModuleName)) {
            Write-Host "Installing $ModuleName module..." "INFO"
            Install-Module $ModuleName -Force -Confirm:$false -Scope CurrentUser -AllowClobber -ErrorAction Stop | Out-Null
        }
        
        # 4. Import and Execute
        Import-Module $ModuleName -ErrorAction Stop
        Write-Host "Downloading and installing updates (No Prompts)..." "INFO"
        
        # -AcceptAll: Automatically accepts all EULAs and Update prompts
        # -AutoReboot:$false: Prevents the machine from restarting while the script is logging
        Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -MicrosoftUpdate -ErrorAction SilentlyContinue
        
        Write-Host "Windows Updates processed." "SUCCESS"
    } catch { 
        Write-Host "Update process skipped: $($_.Exception.Message)" "WARN" 
    }
