# Configuration
$ToolsPath = "C:\SCCMTools"
$LogsPath = Join-Path $ToolsPath "Logs"
$WMILogFile = Join-Path $LogsPath "odrive_wmi.log"
$StatusFile = Join-Path $LogsPath "odrive_current_status.json"
$HistoryFile = Join-Path $LogsPath "odrive_sync_history.log"

# Initialize WMI log file
Write-Output "=== WMI Update Started $(Get-Date) ===" | Out-File -FilePath $WMILogFile -Encoding UTF8
Add-Content -Path $WMILogFile -Value "[DEBUG] Script started. ToolsPath: $ToolsPath, LogsPath: $LogsPath" -Encoding UTF8

# Check if status file exists
Add-Content -Path $WMILogFile -Value "[DEBUG] Checking for status file at: $StatusFile" -Encoding UTF8
if (-not (Test-Path $StatusFile)) {
    Add-Content -Path $WMILogFile -Value "[ERROR] Status file not found" -Encoding UTF8
    return $false
}
Add-Content -Path $WMILogFile -Value "[DEBUG] Status file found" -Encoding UTF8

# Read current status
try {
    Add-Content -Path $WMILogFile -Value "[DEBUG] Attempting to read status file..." -Encoding UTF8
    $status = Get-Content $StatusFile | ConvertFrom-Json
    Add-Content -Path $WMILogFile -Value "[DEBUG] Status file read successfully. Content: $($status | ConvertTo-Json -Compress)" -Encoding UTF8
}
catch {
    Add-Content -Path $WMILogFile -Value "[ERROR] Error reading status file: $($_.Exception.Message)" -Encoding UTF8
    Add-Content -Path $WMILogFile -Value "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
    return $false
}

function Test-WMINamespaceAndClass {
    Add-Content -Path $WMILogFile -Value "[DEBUG] Entering Test-WMINamespaceAndClass function" -Encoding UTF8
    # Check if namespace exists
    $namespace = "ROOT\CANRspace"
    
    Add-Content -Path $WMILogFile -Value "[DEBUG] Checking for namespace: $namespace" -Encoding UTF8
    
    $existingNamespace = Get-WmiObject -Namespace "ROOT" -Class "__NAMESPACE" | Where-Object { $_.Name -eq "CANRspace" }
    Add-Content -Path $WMILogFile -Value "[DEBUG] Existing namespace found: $($null -ne $existingNamespace)" -Encoding UTF8
    
    if (-not $existingNamespace) {
        try {
            Add-Content -Path $WMILogFile -Value "[DEBUG] Attempting to create namespace..." -Encoding UTF8
            $newNamespace = [wmiclass]'ROOT:__NAMESPACE'
            $newNamespace.Create("CANRspace")
            Add-Content -Path $WMILogFile -Value "[DEBUG] Created WMI namespace: $namespace" -Encoding UTF8
        }
        catch {
            Add-Content -Path $WMILogFile -Value "[ERROR] Error creating WMI namespace: $($_.Exception.Message)" -Encoding UTF8
            Add-Content -Path $WMILogFile -Value "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
            return $false
        }
    }

    try {
        Add-Content -Path $WMILogFile -Value "[DEBUG] Checking for OneDrive class in namespace $namespace" -Encoding UTF8
        $classes = Get-WmiObject -Namespace $namespace -List
        Add-Content -Path $WMILogFile -Value "[DEBUG] Found $(($classes | Measure-Object).Count) classes in namespace" -Encoding UTF8
        
        $classExists = [bool]($classes | Where-Object { $_.Name -eq "OneDrive" })
        Add-Content -Path $WMILogFile -Value "[DEBUG] OneDrive class exists: $classExists" -Encoding UTF8
        
        if (-not $classExists) {
            Add-Content -Path $WMILogFile -Value "[DEBUG] Attempting to create OneDrive class..." -Encoding UTF8
            $newClass = New-Object System.Management.ManagementClass($namespace, [string]::Empty, $null)
            $newClass["__CLASS"] = "OneDrive"
            
            # Add properties
            $newClass.Qualifiers.Add("Static", $true)
            
            # Add properties first
            Add-Content -Path $WMILogFile -Value "[DEBUG] Adding properties to new class..." -Encoding UTF8
            $newClass.Properties.Add("last_odsync", "String", $null)
            $newClass.Properties.Add("current_state", "String", $null)
            $newClass.Properties.Add("used_quota", "String", $null)
            $newClass.Properties.Add("total_quota", "String", $null)
            $newClass.Properties.Add("folder_path", "String", $null)
            $newClass.Properties.Add("sync_history", "String", $null)  # Store as delimited string
            $newClass.Properties.Add("last_ran", "String", $null)  # Add timestamp of when WMI was last updated
            $newClass.Properties.Add("configuration_status", "String", $null)  # New property for configuration status
            $newClass.Properties.Add("known_folders_configured", "Boolean", $null)  # New property for known folders status
            $newClass.Properties.Add("error_message", "String", $null)  # New property for error messages
            
            # Then set the key property
            $newClass.Properties["folder_path"].Qualifiers.Add("Key", $true)
            
            $newClass.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "[DEBUG] Successfully created WMI class: OneDrive" -Encoding UTF8
        } else {
            # Check and add any missing properties to the existing class
            Add-Content -Path $WMILogFile -Value "[DEBUG] Checking for missing properties in OneDrive class..." -Encoding UTF8
            
            $existingClass = New-Object System.Management.ManagementClass($namespace, "OneDrive", $null)
            $requiredProperties = @{
                "last_odsync" = "String"
                "current_state" = "String"
                "used_quota" = "String"
                "total_quota" = "String"
                "folder_path" = "String"
                "sync_history" = "String"
                "last_ran" = "String"
                "configuration_status" = "String"
                "known_folders_configured" = "Boolean"
                "error_message" = "String"
            }
            
            $existingProperties = $existingClass.Properties | Select-Object -ExpandProperty Name
            Add-Content -Path $WMILogFile -Value "[DEBUG] Existing properties: $($existingProperties -join ', ')" -Encoding UTF8
            
            $missingProperties = @()
            foreach ($prop in $requiredProperties.GetEnumerator()) {
                if ($existingProperties -notcontains $prop.Key) {
                    $missingProperties += $prop.Key
                }
            }

            if ($missingProperties.Count -gt 0) {
                Add-Content -Path $WMILogFile -Value "[DEBUG] Found missing properties: $($missingProperties -join ', ')" -Encoding UTF8
                
                # If we have missing properties, we need to delete existing instances first
                try {
                    Add-Content -Path $WMILogFile -Value "[DEBUG] Attempting to delete existing instances..." -Encoding UTF8
                    Get-WmiObject -Namespace $namespace -Class "OneDrive" | Remove-WmiObject
                    Add-Content -Path $WMILogFile -Value "[DEBUG] Successfully deleted existing instances" -Encoding UTF8
                    
                    # Now we can update the class
                    foreach ($prop in $missingProperties) {
                        Add-Content -Path $WMILogFile -Value "[DEBUG] Adding missing property: $prop" -Encoding UTF8
                        try {
                            $existingClass.Properties.Add($prop, $requiredProperties[$prop], $null)
                            if ($prop -eq "folder_path") {
                                $existingClass.Properties["folder_path"].Qualifiers.Add("Key", $true)
                            }
                        } catch {
                            Add-Content -Path $WMILogFile -Value "[ERROR] Error adding property ${prop}: $($_.Exception.Message)" -Encoding UTF8
                        }
                    }
                    
                    # Save changes to the class
                    try {
                        $existingClass.Put() | Out-Null
                        Add-Content -Path $WMILogFile -Value "[DEBUG] Successfully updated WMI class properties" -Encoding UTF8
                    } catch {
                        Add-Content -Path $WMILogFile -Value "[ERROR] Error updating WMI class: $($_.Exception.Message)" -Encoding UTF8
                        return $false
                    }
                } catch {
                    Add-Content -Path $WMILogFile -Value "[ERROR] Error deleting instances: $($_.Exception.Message)" -Encoding UTF8
                    return $false
                }
            } else {
                Add-Content -Path $WMILogFile -Value "[DEBUG] No missing properties found" -Encoding UTF8
            }
        }
        Add-Content -Path $WMILogFile -Value "[DEBUG] Exiting Test-WMINamespaceAndClass function successfully" -Encoding UTF8
        return $true
    }
    catch {
        Add-Content -Path $WMILogFile -Value "[ERROR] Error in Test-WMINamespaceAndClass: $($_.Exception.Message)" -Encoding UTF8
        Add-Content -Path $WMILogFile -Value "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
        return $false
    }
}

Add-Content -Path $WMILogFile -Value "[DEBUG] Testing WMI namespace and class..." -Encoding UTF8
if (Test-WMINamespaceAndClass) {
    try {
        Add-Content -Path $WMILogFile -Value "[DEBUG] Attempting to get WMI instance..." -Encoding UTF8
        $wmiInstance = Get-WmiObject -Namespace "ROOT\CANRspace" -Class "OneDrive" -ErrorAction Stop
        
        # Get sync history if available
        $syncHistory = ""
        if (Test-Path $HistoryFile) {
            Add-Content -Path $WMILogFile -Value "[DEBUG] Found sync history file, reading last 10 entries..." -Encoding UTF8
            $syncHistory = (Get-Content -Path $HistoryFile | Select-Object -Last 10) -join '|'
        } else {
            Add-Content -Path $WMILogFile -Value "[DEBUG] No sync history file found, this is normal if known folders are not configured" -Encoding UTF8
        }
        
        if ($wmiInstance) {
            Add-Content -Path $WMILogFile -Value "[DEBUG] Existing WMI instance found" -Encoding UTF8
            
            Add-Content -Path $WMILogFile -Value "[DEBUG] Updating WMI instance with new values..." -Encoding UTF8
            $wmiInstance.last_odsync = $status.LastSync
            $wmiInstance.current_state = $status.CurrentSync
            $wmiInstance.used_quota = $status.UsedQuota
            $wmiInstance.total_quota = $status.TotalQuota
            $wmiInstance.folder_path = $status.FolderPath
            $wmiInstance.sync_history = $syncHistory
            $wmiInstance.last_ran = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
            $wmiInstance.configuration_status = $status.ConfigurationStatus
            $wmiInstance.known_folders_configured = $status.KnownFoldersConfigured
            $wmiInstance.error_message = $status.ErrorMessage
            $wmiInstance.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "[DEBUG] Successfully updated existing WMI instance" -Encoding UTF8
            return $true
        }
        else {
            Add-Content -Path $WMILogFile -Value "[DEBUG] No existing WMI instance found, creating new instance..." -Encoding UTF8
            $wmiInstance = ([WmiClass]"\\.\ROOT\CANRspace:OneDrive").CreateInstance()
            
            Add-Content -Path $WMILogFile -Value "[DEBUG] Setting values for new WMI instance..." -Encoding UTF8
            $wmiInstance.last_odsync = $status.LastSync
            $wmiInstance.current_state = $status.CurrentSync
            $wmiInstance.used_quota = $status.UsedQuota
            $wmiInstance.total_quota = $status.TotalQuota
            $wmiInstance.folder_path = $status.FolderPath
            $wmiInstance.sync_history = $syncHistory
            $wmiInstance.last_ran = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
            $wmiInstance.configuration_status = $status.ConfigurationStatus
            $wmiInstance.known_folders_configured = $status.KnownFoldersConfigured
            $wmiInstance.error_message = $status.ErrorMessage
            $wmiInstance.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "[DEBUG] Successfully created and populated new WMI instance" -Encoding UTF8
            return $true
        }
    }
    catch {
        Add-Content -Path $WMILogFile -Value "[ERROR] Error updating WMI: $($_.Exception.Message)" -Encoding UTF8
        Add-Content -Path $WMILogFile -Value "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
        return $false
    }
}

Add-Content -Path $WMILogFile -Value "[ERROR] Script completed with failure" -Encoding UTF8
return $false 