# Software Update Remediation Script
# This script will check for and install available Windows updates

# Function to check if Windows Update service is running
function Test-WindowsUpdateService {
    $service = Get-Service -Name wuauserv
    if ($service.Status -ne 'Running') {
        Start-Service -Name wuauserv
        Start-Sleep -Seconds 5
    }
}

# Function to check for and install updates
function Install-WindowsUpdates {
    try {
        # Create Windows Update Session
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        # Search for available updates
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")
        
        if ($SearchResult.Updates.Count -gt 0) {
            Write-Output "Found $($SearchResult.Updates.Count) updates to install"
            
            # Create collection of updates to download
            $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($Update in $SearchResult.Updates) {
                $UpdatesToDownload.Add($Update) | Out-Null
            }
            
            # Download updates
            $Downloader = $UpdateSession.CreateUpdateDownloader()
            $Downloader.Updates = $UpdatesToDownload
            $Downloader.Download()
            
            # Create collection of updates to install
            $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($Update in $SearchResult.Updates) {
                if ($Update.IsDownloaded) {
                    $UpdatesToInstall.Add($Update) | Out-Null
                }
            }
            
            # Install updates
            if ($UpdatesToInstall.Count -gt 0) {
                $Installer = $UpdateSession.CreateUpdateInstaller()
                $Installer.Updates = $UpdatesToInstall
                $InstallationResult = $Installer.Install()
                
                # Check installation result
                if ($InstallationResult.ResultCode -eq 2) {
                    Write-Output "Updates installed successfully. A system restart may be required."
                    return $true
                }
                else {
                    Write-Output "Failed to install updates. Result code: $($InstallationResult.ResultCode)"
                    return $false
                }
            }
        }
        else {
            Write-Output "No updates available"
            return $true
        }
    }
    catch {
        Write-Error "Error during update process: $_"
        return $false
    }
}

# Main execution
try {
    # Check Windows Update service
    Test-WindowsUpdateService
    
    # Install updates
    $result = Install-WindowsUpdates
    
    # Return result for SCCM
    if ($result) {
        exit 0
    }
    else {
        exit 1
    }
}
catch {
    Write-Error "Error in remediation script: $_"
    exit 1
} 