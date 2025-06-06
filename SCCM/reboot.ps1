<#
    .SYNOPSIS
        Mandatory Reboot with Log Validation, Age Checks, and Test Override

    .DESCRIPTION
        Triggers a soft reboot if:
        - The last reboot (Event ID 1074) is older than threshold, or
        - No reboot event exists, but logs go back at least $MinLogAge days.
        Skips reboot if logs are too young to trust or reboot is recent.
        Allows testing via C:\reboottest.txt override.

    .NOTES
        Exit Codes:
        0    - Success, no reboot needed
        3010 - Reboot needed and will be triggered
             - Also returned when override file is present
        1001 - Failed to retrieve system logs
        1002 - No system logs found
        1003 - Logs too young to make determination (< MinLogAge days)
#>

$RebootThreshold = 30           # How long since last reboot is too long
$MinLogAge = 14                 # Minimum number of days logs must go back to be considered trustworthy
$Today = Get-Date
$OverrideFile = "C:\reboottest.txt"

# Determine proper registry path based on architecture
$Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
$RebootKey = if ($Architecture -eq "32-bit") {
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reboot"
} else {
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Reboot"
}

# Ensure registry key and value exist
if (-not (Test-Path $RebootKey)) {
    New-Item -Path $RebootKey -Force | Out-Null
}
if (-not (Get-ItemProperty -Path $RebootKey -Name Rebooted -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $RebootKey -Name Rebooted -Value 0 -PropertyType DWORD -Force | Out-Null
}
$Rebooted = (Get-ItemProperty -Path $RebootKey -Name Rebooted).Rebooted

# Check for override
if (Test-Path $OverrideFile) {
    Write-Host "Override file detected: $OverrideFile"
    Write-Host "Override file present - triggering reboot"
    Write-Host "Exit Code: 3010"
    exit 3010
}
else {
    # Try to get the last reboot event
    $LastReboot = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ID = 1074 } -MaxEvents 1 -ErrorAction SilentlyContinue

    if ($LastReboot) {
        $DaysSinceReboot = [math]::Abs((New-TimeSpan -Start $LastReboot.TimeCreated -End $Today).Days)
    }
    else {
        # No reboot event found — check oldest log entry
        try {
            $OldestLogEntry = Get-WinEvent -LogName System -MaxEvents 5000 | Sort-Object TimeCreated | Select-Object -First 1
        } catch {
            Write-Host "Failed to retrieve system log entries: $_"
            Write-Host "Exit Code: 1001"
            exit 1001
        }

        if ($OldestLogEntry) {
            $DaysSinceLogStart = [math]::Abs((New-TimeSpan -Start $OldestLogEntry.TimeCreated -End $Today).Days)
            
            # Only proceed if logs go back far enough to be trustworthy
            if ($DaysSinceLogStart -ge $MinLogAge) {
                if ($DaysSinceLogStart -ge $RebootThreshold) {
                    $DaysSinceReboot = $DaysSinceLogStart
                    Write-Host "Oldest log entry is $DaysSinceLogStart days old - exceeds threshold of $RebootThreshold days."
                } else {
                    Write-Host "Oldest log entry is $DaysSinceLogStart days old - within threshold of $RebootThreshold days."
                    $DaysSinceReboot = $DaysSinceLogStart
                }
            } else {
                Write-Host "Logs only go back $DaysSinceLogStart days, which is less than minimum required age ($MinLogAge days) - skipping reboot for safety."
                Write-Host "Exit Code: 1003"
                exit 1003
            }
        } else {
            Write-Host "No system logs found - skipping reboot for safety."
            Write-Host "Exit Code: 1002"
            exit 1002
        }
    }
}

# Trigger reboot if threshold exceeded and not already flagged
if (($DaysSinceReboot -ge $RebootThreshold) -and ($Rebooted -eq 0)) {
    Set-ItemProperty -Path $RebootKey -Name Rebooted -Value 1 -Type DWORD -Force
    Write-Host "System has exceeded reboot threshold. Reboot will be triggered."
    Write-Host "Days Since Reboot: $DaysSinceReboot"
    Write-Host "Exit Code: 3010"
    exit 3010
}

# Clear reboot flag if system is back within compliance
if (($DaysSinceReboot -lt $RebootThreshold) -and ($Rebooted -eq 1)) {
    Set-ItemProperty -Path $RebootKey -Name Rebooted -Value 0 -Type DWORD -Force
    Write-Host "System is within reboot threshold. Reboot flag cleared."
}

Write-Host "Reboot Threshold: $RebootThreshold"
Write-Host "Days Since Reboot: $DaysSinceReboot"
Write-Host "Rebooted: $Rebooted"
Write-Host "Exit Code: 0"
exit 0
