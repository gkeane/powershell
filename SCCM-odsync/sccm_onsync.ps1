# Log the run date to a file in the SCCM logs directory
$LogPath = "$env:SystemRoot\CCM\Logs"
$ODriveLogFile = "$LogPath\odrive.log"
$ODriveStatusFile = "$LogPath\odrive_status.log"
$ODriveHistoryFile = "$LogPath\odrive_history.log"
$ODriveTeamsFile = "$LogPath\odrive_teams.log"

# Create log directory if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Initialize log file with header
Write-Output "=== ODrive Log Started $(Get-Date) ===" | Out-File -FilePath $ODriveLogFile -Encoding UTF8
Write-Output "Script Path: $PSScriptRoot" | Out-File -FilePath $ODriveLogFile -Append -Encoding UTF8

# Clean up any null characters and empty lines from history file if it exists
if (Test-Path $ODriveHistoryFile) {
    (Get-Content $ODriveHistoryFile) -replace "`0", "" | Set-Content $ODriveHistoryFile
    (Get-Content $ODriveHistoryFile) | Where-Object {$_.trim() -ne "" } | Set-Content $ODriveHistoryFile
}

# Get OneDrive status using ODSyncUtil
Write-Output "Executing ODSyncUtil..." | Out-File -FilePath $ODriveLogFile -Append -Encoding UTF8
$ODStatusArray = & "$PSScriptRoot\ODSyncUtil.exe" | ConvertFrom-Json
Write-Output "ODSyncUtil returned $($ODStatusArray.Count) status entries" | Out-File -FilePath $ODriveLogFile -Append -Encoding UTF8
$ODStatusIndex = 1

if ($ODStatusArray) {
    # Clear the Teams log file at the start of each run
    Write-Output "Run Date: $(Get-Date)" | Out-File -FilePath $ODriveTeamsFile

    ForEach ($ODStatus in $ODStatusArray) {
        # Log all OneDrive statuses
        Write-Output "Status $ODStatusIndex :" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> FolderPath $ODStatusIndex = $($ODStatus.FolderPath)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> StatusString $ODStatusIndex = $($ODStatus.CurrentStatesString)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> CurrentState $ODStatusIndex = $($ODStatus.CurrentState)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> ServiceName $ODStatusIndex = $($ODStatus.ServiceName)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> UsedQuota $ODStatusIndex = $($ODStatus.UsedQuota)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> TotalQuota $ODStatusIndex = $($ODStatus.TotalQuota)" | Out-File -FilePath $ODriveLogFile -Append
        Write-Output "> QuotaLabel $ODStatusIndex = $($ODStatus.QuotaLabel)" | Out-File -FilePath $ODriveLogFile -Append

        # If this is the user's OneDrive, log to status and history files
        if ($($env:OneDrive) -eq $($ODStatus.FolderPath)) {
            # Log to history file
            Write-Output "$(Get-Date): $($ODStatus.CurrentStateString)" | Out-File -FilePath $ODriveHistoryFile -Append -Encoding UTF8
            
            # Log current status
            Write-Output "Run Date: $(Get-Date)" | Out-File -FilePath $ODriveStatusFile
            Write-Output "Status $ODStatusIndex :" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> FolderPath $ODStatusIndex = $($ODStatus.FolderPath)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> StatusString $ODStatusIndex = $($ODStatus.CurrentStateString)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> CurrentState $ODStatusIndex = $($ODStatus.CurrentState)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> ServiceName $ODStatusIndex = $($ODStatus.ServiceName)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> UsedQuota $ODStatusIndex = $($ODStatus.UsedQuota)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> TotalQuota $ODStatusIndex = $($ODStatus.TotalQuota)" | Out-File -FilePath $ODriveStatusFile -Append
            Write-Output "> QuotaLabel $ODStatusIndex = $($ODStatus.QuotaLabel)" | Out-File -FilePath $ODriveStatusFile -Append
        }
        else {
            # Log non-user OneDrive statuses to Teams log file
            Write-Output "Status $ODStatusIndex :" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> FolderPath $ODStatusIndex = $($ODStatus.FolderPath)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> StatusString $ODStatusIndex = $($ODStatus.CurrentStatesString)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> CurrentState $ODStatusIndex = $($ODStatus.CurrentState)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> ServiceName $ODStatusIndex = $($ODStatus.ServiceName)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> UsedQuota $ODStatusIndex = $($ODStatus.UsedQuota)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> TotalQuota $ODStatusIndex = $($ODStatus.TotalQuota)" | Out-File -FilePath $ODriveTeamsFile -Append
            Write-Output "> QuotaLabel $ODStatusIndex = $($ODStatus.QuotaLabel)" | Out-File -FilePath $ODriveTeamsFile -Append
        }
        $ODStatusIndex++
    }
}