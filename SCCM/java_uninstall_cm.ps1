# Set up logging
$LogPath = "$env:windir\Logs\Software"
$LogFile = "JavaUninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$MsiLogPath = "$LogPath\MSI"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $MsiLogPath)) {
    New-Item -Path $MsiLogPath -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Output $LogMessage
    Add-Content -Path "$LogPath\$LogFile" -Value $LogMessage
}

Write-Log "Starting Java 8 uninstallation process..."

# Function to handle uninstallation
function Uninstall-Java {
    param (
        [string]$RegistryPath
    )
    
    # Get list of installed software from the registry
    $installedSoftware = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue | 
        Select-Object DisplayName, UninstallString, PSChildName
    
    # Filter out entries without a DisplayName
    $installedSoftware = $installedSoftware | Where-Object { $_.DisplayName -ne $null }
    
    # Find Java 8 entries
    $javaInstalls = $installedSoftware | Where-Object { $_.DisplayName -like "*Java*8*" }
    
    foreach ($java in $javaInstalls) {
        Write-Log "Found: $($java.DisplayName)"
        Write-Log "Uninstall string: $($java.UninstallString)"
        
        try {
            if ($java.UninstallString -match "{[A-F0-9-]+}") {
                $productCode = $matches[0]
            } else {
                $productCode = $java.PSChildName
            }

            # Create unique log file name for this uninstallation
            $msiLogFile = Join-Path $MsiLogPath "JavaUninstall_$($productCode.Replace('{','').Replace('}',''))_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Write-Log "MSI log will be written to: $msiLogFile"
            
            Write-Log "Attempting to uninstall using product code: $productCode"
            $process = Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn /l*v `"$msiLogFile`"" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Log "Successfully uninstalled: $($java.DisplayName)"
            } else {
                Write-Log "Failed to uninstall: $($java.DisplayName) - Exit code: $($process.ExitCode)"
            }

            # Read and append MSI log content to main log if it exists
            if (Test-Path $msiLogFile) {
                Write-Log "=== MSI Log Content for $($java.DisplayName) ==="
                Get-Content $msiLogFile | ForEach-Object {
                    # Filter for important MSI log entries
                    if ($_ -match "Error|Warning|Info.*:|Return Value|Action start|Action ended") {
                        Write-Log "MSI: $_"
                    }
                }
                Write-Log "=== End MSI Log Content ==="
            } else {
                Write-Log "Warning: MSI log file was not created"
            }
        } catch {
            Write-Log "Error during uninstallation: $_"
        }
    }
    
    return $javaInstalls
}

# Check 64-bit installations
Write-Log "Checking 64-bit Java installations..."
$java64 = Uninstall-Java -RegistryPath "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"

# Check 32-bit installations
Write-Log "Checking 32-bit Java installations..."
$java32 = Uninstall-Java -RegistryPath "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"

# Verify results
if (-not $java64 -and -not $java32) {
    Write-Log "No Java 8 installations were found."
} else {
    Write-Log "Uninstallation attempts completed. Verifying..."
    
    # Verify removal
    $remainingJava = @(
        Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue,
        Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
    ) | Where-Object { $_.DisplayName -like "*Java*8*" }
    
    if ($remainingJava) {
        Write-Log "Warning: Some Java 8 installations may remain:"
        foreach ($install in $remainingJava) {
            Write-Log "Remaining: $($install.DisplayName)"
        }
    } else {
        Write-Log "All detected Java 8 installations have been removed."
    }
}

# Trigger SCCM Hardware Inventory
Write-Log "Triggering SCCM Hardware Inventory..."
try {
    $HardwareInventoryID = "{00000000-0000-0000-0000-000000000001}"
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule $HardwareInventoryID
    Write-Log "SCCM Hardware Inventory triggered successfully"
} catch {
    Write-Log "Failed to trigger SCCM Hardware Inventory: $_"
}

Write-Log "Script execution completed. Recommend rebooting the system."