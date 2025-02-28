# Email configuration
$smtpServer = "mail.udel.edu"
$from = "kace@udel.edu"
$to = "it-help@udel.edu"  # Adjust recipient as needed

# Read match and last sync status
try {
    $pathMatch = Get-Content -Path "C:\ProgramData\Quest\KACE\user\odrive_match.txt"
    $lastSync = Get-Content -Path "C:\ProgramData\Quest\KACE\user\odrive_lastsync.txt"
    $currentUser = $env:USERNAME
    $computerName = $env:COMPUTERNAME

    # Only proceed if paths match
    if ($pathMatch -eq "true") {
        $lastSyncDate = [datetime]::ParseExact($lastSync, "MM/dd/yyyy HH:mm:ss", $null)
        $daysSinceSync = (Get-Date) - $lastSyncDate
        
        # Check if more than 90 days since last sync
        if ($daysSinceSync.Days -gt 90) {
            # Prepare email content
            $subject = "OneDrive Inactive Alert - $computerName - $currentUser"
            $body = @"
OneDrive Sync Issue Detected

Computer: $computerName
User: $currentUser
Last Sync: $lastSync
Days Since Sync: $($daysSinceSync.Days)

This OneDrive account has not synced in over 90 days. Please investigate.
"@

            # Send email
            Send-MailMessage -SmtpServer $smtpServer `
                           -From $from `
                           -To $to `
                           -Subject $subject `
                           -Body $body `
                           -Priority High

            # Log the alert
            $logEntry = "$(Get-Date) - Alert sent for $currentUser on $computerName - Last sync: $lastSync"
            Add-Content -Path "C:\ProgramData\Quest\KACE\user\onedrive_alerts.log" -Value $logEntry
        }
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $logEntry = "$(Get-Date) - Error checking sync status: $errorMessage"
    Add-Content -Path "C:\ProgramData\Quest\KACE\user\onedrive_alerts.log" -Value $logEntry
} 