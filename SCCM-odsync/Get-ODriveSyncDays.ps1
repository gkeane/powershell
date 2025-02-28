# Configuration
$ToolsPath = "C:\SCCMTools"
$LogsPath = Join-Path $ToolsPath "Logs"
$ODriveHistoryFile = Join-Path $LogsPath "odrive_sync_history.log"

# Check if history file exists
if (-not (Test-Path $ODriveHistoryFile)) {
    Write-Host "No sync history found"
    return 1000
}

try {
    # Get last sync entry
    $syncedEntries = Get-Content $ODriveHistoryFile | Where-Object { $_ -match ': Synced$' }
    
    if ($syncedEntries) {
        $lastSynced = $syncedEntries | Select-Object -Last 1
        
        if ($lastSynced -match '(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced') {
            $lastSyncDate = [DateTime]::ParseExact($matches[1], "MM/dd/yyyy HH:mm:ss", $null)
            $daysSinceSync = [Math]::Floor(((Get-Date) - $lastSyncDate).TotalDays)
            return $daysSinceSync
        }
    }
    
    # No sync entries found
    Write-Host "No sync entries found in history"
    return 1000
}
catch {
    Write-Host "Error processing sync history: $($_.Exception.Message)"
    return 1000
} 