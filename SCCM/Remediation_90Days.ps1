# Moderate Remediation Script (90-180 days out of date)
# This script performs more aggressive update checks and installations

# Function to check and fix Windows Update components
function Repair-WindowsUpdateComponents {
    try {
        # Stop Windows Update services and prevent auto-restart
        $services = @('wuauserv', 'bits', 'cryptsvc')
        foreach ($service in $services) {
            # Stop the service
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            
            # Set startup to manual to prevent auto-restart
            Set-Service -Name $service -StartupType Manual
            
            # Wait for service to fully stop
            $serviceObj = Get-Service -Name $service
            $timeout = 30
            $timer = 0
            while ($serviceObj.Status -eq 'Running' -and $timer -lt $timeout) {
                Start-Sleep -Seconds 1
                $timer++
                $serviceObj = Get-Service -Name $service
            }
            
            # Force stop if still running
            if ($serviceObj.Status -eq 'Running') {
                $process = Get-Process | Where-Object { $_.Name -like "*$service*" }
                if ($process) {
                    Stop-Process -Id $process.Id -Force
                }
            }
        }
        
        # Delete Windows Update cache
        Remove-Item -Path "$env:windir\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Reset Windows Update components
        $commands = @(
            "net stop wuauserv",
            "net stop bits",
            "net stop cryptsvc",
            "ren %systemroot%\SoftwareDistribution SoftwareDistribution.bak",
            "ren %systemroot%\System32\catroot2 catroot2.bak",
            "net start cryptsvc",
            "net start bits",
            "net start wuauserv"
        )
        
        foreach ($command in $commands) {
            cmd.exe /c $command
            Start-Sleep -Seconds 2
        }
        
        # Start services and set back to automatic
        foreach ($service in $services) {
            Set-Service -Name $service -StartupType Automatic
            Start-Service -Name $service
        }
        Start-Sleep -Seconds 5
    }
    catch {
        Write-Error "Error repairing Windows Update components: $_"
    }
}

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

# Function to run SFC scan
function Run-SFCScan {
    try {
        Write-Output "Running System File Checker scan..."
        $sfcResult = sfc /scannow
        Write-Output $sfcResult
        return $true
    }
    catch {
        Write-Error "Error running SFC scan: $_"
        return $false
    }
}

# Function to run DISM scan and repair
function Run-DISMScan {
    try {
        Write-Output "Running DISM scan and repair..."
        
        # Check health
        Write-Output "Checking component store health..."
        $dismCheck = DISM /Online /Cleanup-Image /CheckHealth
        Write-Output $dismCheck
        
        # Scan health
        Write-Output "Scanning component store health..."
        $dismScan = DISM /Online /Cleanup-Image /ScanHealth
        Write-Output $dismScan
        
        # Restore health
        Write-Output "Restoring component store health..."
        $dismRestore = DISM /Online /Cleanup-Image /RestoreHealth
        Write-Output $dismRestore
        
        return $true
    }
    catch {
        Write-Error "Error running DISM scan: $_"
        return $false
    }
}

# Main execution
try {
    # Run SFC scan
    Run-SFCScan
    
    # Run DISM scan and repair
    Run-DISMScan
    
    # Repair Windows Update components
    Repair-WindowsUpdateComponents
    
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