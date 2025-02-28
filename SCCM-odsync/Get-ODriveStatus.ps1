# Configuration
$ToolsPath = "C:\SCCMTools"
$LogsPath = Join-Path $ToolsPath "Logs"
$ODriveLogFile = Join-Path $LogsPath "odrive_status.log"
$ODriveHistoryFile = Join-Path $LogsPath "odrive_sync_history.log"
$ODriveStatusFile = Join-Path $LogsPath "odrive_current_status.json"

# Initialize log file
Write-Output "=== ODrive Status Check Started $(Get-Date) ===" | Out-File -FilePath $ODriveLogFile -Encoding UTF8

# Verify ODSyncUtil exists
$ODSyncUtilPath = Join-Path $ToolsPath "ODSyncUtil.exe"
if (-not (Test-Path $ODSyncUtilPath)) {
    Add-Content -Path $ODriveLogFile -Value "ODSyncUtil.exe not found in $ToolsPath" -Encoding UTF8
    return $false
}

# Get OneDrive status using ODSyncUtil
$ODStatusArray = & $ODSyncUtilPath | ConvertFrom-Json

if (-not $ODStatusArray) {
    Add-Content -Path $ODriveLogFile -Value "No OneDrive status data returned" -Encoding UTF8
    return $false
}

# Verify we're checking the correct user's OneDrive
$userOneDrivePath = $env:OneDrive
if (-not ($ODStatusArray | Where-Object { $_.FolderPath -eq $userOneDrivePath })) {
    Add-Content -Path $ODriveLogFile -Value "No matching OneDrive folder found for current user path: $userOneDrivePath" -Encoding UTF8
    return $false
}

# Use the matching OneDrive status
$ODStatus = $ODStatusArray | Where-Object { $_.FolderPath -eq $userOneDrivePath }

# After logging current status but before checking history
$currentTime = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
Add-Content -Path $ODriveHistoryFile -Value ($currentTime + ": " + $ODStatus.CurrentStateString) -Encoding UTF8

# Trim history file to keep minimum 20 entries and all since last sync
$historyEntries = Get-Content $ODriveHistoryFile
$lastSyncIndex = ($historyEntries | Select-String -Pattern ': Synced$').LineNumber | Select-Object -Last 1

if ($lastSyncIndex) {
    # Calculate how many entries to keep
    $entriesToKeep = [Math]::Max(20, $historyEntries.Count - $lastSyncIndex + 1)
    $historyEntries | Select-Object -Last $entriesToKeep | Set-Content $ODriveHistoryFile -Encoding UTF8
} else {
    # If no sync found, keep all entries (up to a reasonable limit, say 100)
    $historyEntries | Select-Object -Last 100 | Set-Content $ODriveHistoryFile -Encoding UTF8
}

# Check history for last successful sync
if (Test-Path $ODriveHistoryFile) {
    $syncedEntries = Get-Content $ODriveHistoryFile | Where-Object { $_ -match ': Synced$' }
    
    if ($syncedEntries) {
        $lastSynced = $syncedEntries | Select-Object -Last 1
        
        if ($lastSynced -match '(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced') {
            $dateString = $matches[1]
            $lastSyncDate = [DateTime]::ParseExact($dateString, "MM/dd/yyyy HH:mm:ss", $null)
            
            # Create status object with the correct OneDrive instance
            $status = @{
                LastSync = $lastSyncDate.ToString("MM/dd/yyyy HH:mm:ss")
                CurrentSync = $ODStatus.CurrentStateString
                UsedQuota = $ODStatus.UsedQuota
                TotalQuota = $ODStatus.TotalQuota
                FolderPath = $ODStatus.FolderPath
            }
            
            # Save status to temp file for WMI update
            $status | ConvertTo-Json | Out-File $ODriveStatusFile -Encoding UTF8
            return $true
        }
    }
}

return $false 