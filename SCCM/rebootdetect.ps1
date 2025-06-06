<#
    .SYNOPSIS
        Reboot Days Detection for SCCM Configuration Items

    .DESCRIPTION
        Returns the number of days since last reboot as an integer.
        SCCM compliance rule should be set to GreaterThan 30 for non-compliance.
        Uses a test file override and safely handles missing event logs.
        Designed specifically for SCCM Configuration Item compliance rules.
#>

try {
    $RebootThreshold = 30
    $MinLogAge = 14        # Minimum days of log history required to trust no-reboot condition
    $Today = Get-Date
    $OverrideFile = "C:\reboottest.txt"

    # Determine OS architecture
    $Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    $RebootKey = if ($Architecture -eq "32-bit") {
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reboot"
    } else {
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Reboot"
    }

    # Ensure registry key/value exists
    if (-not (Test-Path $RebootKey)) {
        New-Item -Path $RebootKey -Force | Out-Null
    }
    if (-not (Get-ItemProperty -Path $RebootKey -Name Rebooted -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $RebootKey -Name Rebooted -Value 0 -PropertyType DWORD -Force | Out-Null
    }
    $Rebooted = (Get-ItemProperty -Path $RebootKey -Name Rebooted).Rebooted

    # Get last reboot time using more reliable method
    $LastReboot = $null
    try {
        $LastReboot = Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 1074} -MaxEvents 1 -ErrorAction Stop
    }
    catch {
        # Fallback to WMI if Get-WinEvent fails
        try {
            $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            if ($LastBootUpTime) {
                # Create a mock object similar to WinEvent for consistency
                $LastReboot = [PSCustomObject]@{
                    TimeCreated = $LastBootUpTime
                }
            }
        }
        catch {
            $LastReboot = $null
        }
    }

    # If override file exists, return high number to indicate non-compliance
    if (Test-Path $OverrideFile) {
        return 9999  # High number indicates forced non-compliance
    }

    # If no reboot event found, check system log age
    if (-not $LastReboot) {
        try {
            # Use a more conservative approach to get oldest log entry
            $OldestLogEntry = Get-WinEvent -LogName System -MaxEvents 1000 -ErrorAction Stop | 
                Sort-Object TimeCreated | Select-Object -First 1
            
            if ($OldestLogEntry) {
                $DaysSinceLogStart = [math]::Abs((New-TimeSpan -Start $OldestLogEntry.TimeCreated -End $Today).Days)
                
                # If logs are at least MinLogAge days old, return high number for non-compliance
                if ($DaysSinceLogStart -ge $MinLogAge) {
                    return 9998  # High number - no reboot found in sufficient log history
                }
                # If logs are too young, return low number for compliance
                else {
                    return 0     # Compliant - insufficient log history to determine
                }
            }
            else {
                # No logs found, assume recent reboot
                return 0
            }
        }
        catch {
            # Error accessing logs, assume recent reboot
            return 0
        }
    }

    # Calculate days since reboot
    $DaysSinceReboot = [math]::Round((New-TimeSpan -Start $LastReboot.TimeCreated -End $Today).TotalDays)
    
    # Return the actual number of days since reboot
    return [int]$DaysSinceReboot

}
catch {
    # If any unexpected error occurs, return 0 for safety
    return 0
}
