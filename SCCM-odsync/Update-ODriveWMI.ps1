# Configuration
$ToolsPath = "C:\SCCMTools"
$LogsPath = Join-Path $ToolsPath "Logs"
$WMILogFile = Join-Path $LogsPath "odrive_wmi.log"
$StatusFile = Join-Path $LogsPath "odrive_current_status.json"

# Initialize WMI log file
Write-Output "=== WMI Update Started $(Get-Date) ===" | Out-File -FilePath $WMILogFile -Encoding UTF8

# Check if status file exists
if (-not (Test-Path $StatusFile)) {
    Add-Content -Path $WMILogFile -Value "Status file not found" -Encoding UTF8
    return $false
}

# Read current status
try {
    $status = Get-Content $StatusFile | ConvertFrom-Json
}
catch {
    Add-Content -Path $WMILogFile -Value "Error reading status file: $($_.Exception.Message)" -Encoding UTF8
    return $false
}

function Test-WMINamespaceAndClass {
    # Check if namespace exists
    $namespace = "ROOT\CANRspace"
    
    Add-Content -Path $WMILogFile -Value "Checking for namespace: $namespace" -Encoding UTF8
    
    $existingNamespace = Get-WmiObject -Namespace "ROOT" -Class "__NAMESPACE" | Where-Object { $_.Name -eq "CANRspace" }
    Add-Content -Path $WMILogFile -Value "Existing namespace found: $($null -ne $existingNamespace)" -Encoding UTF8
    
    if (-not $existingNamespace) {
        try {
            Add-Content -Path $WMILogFile -Value "Attempting to create namespace..." -Encoding UTF8
            $newNamespace = [wmiclass]'ROOT:__NAMESPACE'
            $newNamespace.Create("CANRspace")
            Add-Content -Path $WMILogFile -Value "Created WMI namespace: $namespace" -Encoding UTF8
        }
        catch {
            Add-Content -Path $WMILogFile -Value "Error creating WMI namespace: $($_.Exception.Message)" -Encoding UTF8
            Add-Content -Path $WMILogFile -Value "Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
            return $false
        }
    }

    try {
        Add-Content -Path $WMILogFile -Value "Checking for OneDrive class in namespace $namespace" -Encoding UTF8
        $classes = Get-WmiObject -Namespace $namespace -List
        Add-Content -Path $WMILogFile -Value "Found $(($classes | Measure-Object).Count) classes in namespace" -Encoding UTF8
        
        $classExists = [bool]($classes | Where-Object { $_.Name -eq "OneDrive" })
        Add-Content -Path $WMILogFile -Value "OneDrive class exists: $classExists" -Encoding UTF8
        
        if (-not $classExists) {
            Add-Content -Path $WMILogFile -Value "Attempting to create OneDrive class..." -Encoding UTF8
            $newClass = New-Object System.Management.ManagementClass($namespace, [string]::Empty, $null)
            $newClass["__CLASS"] = "OneDrive"
            
            # Add properties
            $newClass.Qualifiers.Add("Static", $true)
            
            # Add properties first
            $newClass.Properties.Add("last_odsync", "String", $null)
            $newClass.Properties.Add("current_state", "String", $null)
            $newClass.Properties.Add("used_quota", "String", $null)
            $newClass.Properties.Add("total_quota", "String", $null)
            $newClass.Properties.Add("folder_path", "String", $null)
            $newClass.Properties.Add("sync_history", "String", $null)  # Store as delimited string
            $newClass.Properties.Add("last_ran", "String", $null)  # Add timestamp of when WMI was last updated
            
            # Then set the key property
            $newClass.Properties["folder_path"].Qualifiers.Add("Key", $true)
            
            $newClass.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "Successfully created WMI class: OneDrive" -Encoding UTF8
        } else {
            # Check and add any missing properties to the existing class
            Add-Content -Path $WMILogFile -Value "Checking for missing properties in OneDrive class..." -Encoding UTF8
            
            $existingClass = New-Object System.Management.ManagementClass($namespace, "OneDrive", $null)
            $requiredProperties = @{
                "last_odsync" = "String"
                "current_state" = "String"
                "used_quota" = "String"
                "total_quota" = "String"
                "folder_path" = "String"
                "sync_history" = "String"
                "last_ran" = "String"
            }
            
            $existingProperties = $existingClass.Properties | Select-Object -ExpandProperty Name
            
            foreach ($prop in $requiredProperties.GetEnumerator()) {
                if ($existingProperties -notcontains $prop.Key) {
                    Add-Content -Path $WMILogFile -Value "Adding missing property: $($prop.Key)" -Encoding UTF8
                    try {
                        $existingClass.Properties.Add($prop.Key, $prop.Value, $null)
                        if ($prop.Key -eq "folder_path") {
                            $existingClass.Properties["folder_path"].Qualifiers.Add("Key", $true)
                        }
                    } catch {
                        Add-Content -Path $WMILogFile -Value "Error adding property $($prop.Key): $($_.Exception.Message)" -Encoding UTF8
                    }
                }
            }
            
            # Save any changes to the class
            try {
                $existingClass.Put() | Out-Null
                Add-Content -Path $WMILogFile -Value "Successfully updated WMI class properties" -Encoding UTF8
            } catch {
                Add-Content -Path $WMILogFile -Value "Error updating WMI class: $($_.Exception.Message)" -Encoding UTF8
                return $false
            }
        }
        return $true
    }
    catch {
        Add-Content -Path $WMILogFile -Value "Error creating/checking WMI class: $($_.Exception.Message)" -Encoding UTF8
        Add-Content -Path $WMILogFile -Value "Stack trace: $($_.ScriptStackTrace)" -Encoding UTF8
        return $false
    }
}

if (Test-WMINamespaceAndClass) {
    try {
        $wmiInstance = Get-WmiObject -Namespace "ROOT\CANRspace" -Class "OneDrive" -ErrorAction Stop
        
        if ($wmiInstance) {
            # Get last 10 history entries as pipe-delimited string
            $syncHistory = (Get-Content -Path (Join-Path $LogsPath "odrive_sync_history.log") | 
                Select-Object -Last 10) -join '|'
            
            $wmiInstance.last_odsync = $status.LastSync
            $wmiInstance.current_state = $status.CurrentSync
            $wmiInstance.used_quota = $status.UsedQuota
            $wmiInstance.total_quota = $status.TotalQuota
            $wmiInstance.folder_path = $status.FolderPath
            $wmiInstance.sync_history = $syncHistory
            $wmiInstance.last_ran = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
            $wmiInstance.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "Updated WMI with last sync time and quotas" -Encoding UTF8
            return $true
        }
        else {
            $wmiInstance = ([WmiClass]"\\.\ROOT\CANRspace:OneDrive").CreateInstance()
            
            # Get last 10 history entries as pipe-delimited string
            $syncHistory = (Get-Content -Path (Join-Path $LogsPath "odrive_sync_history.log") | 
                Select-Object -Last 10) -join '|'
            
            $wmiInstance.last_odsync = $status.LastSync
            $wmiInstance.current_state = $status.CurrentSync
            $wmiInstance.used_quota = $status.UsedQuota
            $wmiInstance.total_quota = $status.TotalQuota
            $wmiInstance.folder_path = $status.FolderPath
            $wmiInstance.sync_history = $syncHistory
            $wmiInstance.last_ran = (Get-Date).ToString("MM/dd/yyyy HH:mm:ss")
            $wmiInstance.Put() | Out-Null
            Add-Content -Path $WMILogFile -Value "Created new WMI instance with sync time and quotas" -Encoding UTF8
            return $true
        }
    }
    catch {
        Add-Content -Path $WMILogFile -Value "Error updating WMI: $($_.Exception.Message)" -Encoding UTF8
        return $false
    }
}

return $false 