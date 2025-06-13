# Configuration
$ToolsPath = "C:\SCCMTools"
$LogsPath = Join-Path $ToolsPath "Logs"
$ODriveLogFile = Join-Path $LogsPath "odrive_status.log"
$ODriveHistoryFile = Join-Path $LogsPath "odrive_sync_history.log"
$ODriveStatusFile = Join-Path $LogsPath "odrive_current_status.json"

# Initialize log file
Write-Output "=== ODrive Status Check Started $(Get-Date) ===" | Out-File -FilePath $ODriveLogFile -Encoding UTF8
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Script started. ToolsPath: $ToolsPath, LogsPath: $LogsPath" -Encoding UTF8

# Check if OneDrive is configured
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Checking if OneDrive is configured..." -Encoding UTF8
if (-not $env:OneDrive) {
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] OneDrive environment variable not found. OneDrive may not be configured." -Encoding UTF8
    $status = @{
        LastSync = "Never"
        CurrentSync = "Not Configured"
        UsedQuota = "0"
        TotalQuota = "0"
        FolderPath = "Not Configured"
        ConfigurationStatus = "Not Configured"
        ErrorMessage = "OneDrive is not configured on this system"
    }
    $status | ConvertTo-Json | Out-File $ODriveStatusFile -Encoding UTF8
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Status written to $ODriveStatusFile for unconfigured state" -Encoding UTF8
    return $false
}

# Verify ODSyncUtil exists
$ODSyncUtilPath = Join-Path $ToolsPath "ODSyncUtil.exe"
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Checking for ODSyncUtil.exe at $ODSyncUtilPath" -Encoding UTF8
if (-not (Test-Path $ODSyncUtilPath)) {
    Add-Content -Path $ODriveLogFile -Value "ODSyncUtil.exe not found in $ToolsPath" -Encoding UTF8
    return $false
}
Add-Content -Path $ODriveLogFile -Value "[DEBUG] ODSyncUtil.exe found." -Encoding UTF8

# Get OneDrive status using ODSyncUtil
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Running ODSyncUtil.exe..." -Encoding UTF8
$ODStatusArray = & $ODSyncUtilPath | ConvertFrom-Json
Add-Content -Path $ODriveLogFile -Value "[DEBUG] ODSyncUtil.exe completed. ODSyncUtil output count: $($ODStatusArray.Count)" -Encoding UTF8

if (-not $ODStatusArray) {
    Add-Content -Path $ODriveLogFile -Value "No OneDrive status data returned" -Encoding UTF8
    $status = @{
        LastSync = "Never"
        CurrentSync = "Error"
        UsedQuota = "0"
        TotalQuota = "0"
        FolderPath = $env:OneDrive
        ConfigurationStatus = "Error"
        ErrorMessage = "No OneDrive status data returned from ODSyncUtil"
    }
    $status | ConvertTo-Json | Out-File $ODriveStatusFile -Encoding UTF8
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Status written to $ODriveStatusFile for error state" -Encoding UTF8
    return $false
}
Add-Content -Path $ODriveLogFile -Value "[DEBUG] ODSyncUtil returned data." -Encoding UTF8

# Verify we're checking the correct user's OneDrive
$userOneDrivePath = $env:OneDrive
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Current user's OneDrive path: $userOneDrivePath" -Encoding UTF8
if (-not ($ODStatusArray | Where-Object { $_.FolderPath -eq $userOneDrivePath })) {
    Add-Content -Path $ODriveLogFile -Value "No matching OneDrive folder found for current user path: $userOneDrivePath" -Encoding UTF8
    $status = @{
        LastSync = "Never"
        CurrentSync = "Not Found"
        UsedQuota = "0"
        TotalQuota = "0"
        FolderPath = $userOneDrivePath
        ConfigurationStatus = "Not Found"
        ErrorMessage = "No matching OneDrive folder found for current user"
    }
    $status | ConvertTo-Json | Out-File $ODriveStatusFile -Encoding UTF8
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Status written to $ODriveStatusFile for not found state" -Encoding UTF8
    return $false
}
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Matching OneDrive folder found." -Encoding UTF8

# Use the matching OneDrive status
$ODStatus = $ODStatusArray | Where-Object { $_.FolderPath -eq $userOneDrivePath }
Add-Content -Path $ODriveLogFile -Value "[DEBUG] ODStatus object: $($ODStatus | ConvertTo-Json -Compress)" -Encoding UTF8

# Check if known folders are configured
$knownFoldersConfigured = $false
try {
    $knownFolders = Get-ChildItem -Path $userOneDrivePath -Directory | Where-Object { $_.Name -in @("Documents", "Pictures", "Desktop") }
    $knownFoldersConfigured = $knownFolders.Count -gt 0
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Known folders configured: $knownFoldersConfigured" -Encoding UTF8
} catch {
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Error checking known folders: $($_.Exception.Message)" -Encoding UTF8
}

# After logging current status but before checking history
$currentTime = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Logging current status to history file." -Encoding UTF8
Add-Content -Path $ODriveHistoryFile -Value ($currentTime + ": " + $ODStatus.CurrentStateString) -Encoding UTF8

# Trim history file to keep minimum 20 entries and all since last sync
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Trimming history file if needed." -Encoding UTF8
$historyEntries = Get-Content $ODriveHistoryFile
$lastSyncIndex = ($historyEntries | Select-String -Pattern ': Synced$').LineNumber | Select-Object -Last 1
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Last sync index: $lastSyncIndex, Total history entries: $($historyEntries.Count)" -Encoding UTF8

if ($lastSyncIndex) {
    # Calculate how many entries to keep
    $entriesToKeep = [Math]::Max(20, $historyEntries.Count - $lastSyncIndex + 1)
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Keeping last $entriesToKeep entries in history file." -Encoding UTF8
    $historyEntries | Select-Object -Last $entriesToKeep | Set-Content $ODriveHistoryFile -Encoding UTF8
} else {
    # If no sync found, keep all entries (up to a reasonable limit, say 100)
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] No sync found, keeping last 100 entries." -Encoding UTF8
    $historyEntries | Select-Object -Last 100 | Set-Content $ODriveHistoryFile -Encoding UTF8
}

# Check history for last successful sync
Add-Content -Path $ODriveLogFile -Value "[DEBUG] Checking history for last successful sync." -Encoding UTF8
if (Test-Path $ODriveHistoryFile) {
    $syncedEntries = Get-Content $ODriveHistoryFile | Where-Object { $_ -match ': Synced$' }
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] Synced entries count: $($syncedEntries.Count)" -Encoding UTF8
    
    if ($syncedEntries) {
        $lastSynced = $syncedEntries | Select-Object -Last 1
        Add-Content -Path $ODriveLogFile -Value "[DEBUG] Last synced entry: $lastSynced" -Encoding UTF8
        
        if ($lastSynced -match '(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced') {
            $dateString = $matches[1]
            $lastSyncDate = [DateTime]::ParseExact($dateString, "MM/dd/yyyy HH:mm:ss", $null)
            Add-Content -Path $ODriveLogFile -Value "[DEBUG] Last sync date parsed: $lastSyncDate" -Encoding UTF8
            
            # Create status object with the correct OneDrive instance
            $status = @{
                LastSync = $lastSyncDate.ToString("MM/dd/yyyy HH:mm:ss")
                CurrentSync = $ODStatus.CurrentStateString
                UsedQuota = $ODStatus.UsedQuota
                TotalQuota = $ODStatus.TotalQuota
                FolderPath = $ODStatus.FolderPath
                ConfigurationStatus = if ($knownFoldersConfigured) { "Configured" } else { "Not Configured" }
                KnownFoldersConfigured = $knownFoldersConfigured
            }
            Add-Content -Path $ODriveLogFile -Value "[DEBUG] Status object: $($status | ConvertTo-Json -Compress)" -Encoding UTF8
            
            # Save status to temp file for WMI update
            $status | ConvertTo-Json | Out-File $ODriveStatusFile -Encoding UTF8
            Add-Content -Path $ODriveLogFile -Value "[DEBUG] Status written to $ODriveStatusFile" -Encoding UTF8
            return $true
        } else {
            Add-Content -Path $ODriveLogFile -Value "[DEBUG] Last synced entry did not match expected pattern." -Encoding UTF8
        }
    } else {
        Add-Content -Path $ODriveLogFile -Value "[DEBUG] No synced entries found in history." -Encoding UTF8
    }
} else {
    Add-Content -Path $ODriveLogFile -Value "[DEBUG] ODriveHistoryFile does not exist." -Encoding UTF8
}

Add-Content -Path $ODriveLogFile -Value "[DEBUG] Script completed with failure." -Encoding UTF8
return $false 