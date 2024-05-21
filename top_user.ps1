# Define a hashtable to store user login durations
$userLoginDurations = @{}

# Get logon events, specifically filtering for interactive logons (Type 2 and 10)
$logonEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} | Where-Object {
    $eventXml = [xml]$_.ToXml()
    $logonType = $eventXml.Event.EventData.Data | Where-Object {$_.Name -eq 'LogonType'} | Select-Object -ExpandProperty '#text'
    $logonType -eq '2' -or $logonType -eq '10'
}

# Get logoff events
$logoffEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4634,4647}

# Process logon events
foreach ($event in $logonEvents) {
    $eventXml = [xml]$event.ToXml()
    $username = $eventXml.Event.EventData.Data | Where-Object {$_.Name -eq 'TargetUserName'} | Select-Object -ExpandProperty '#text'
    $logonTime = $event.TimeCreated

    # Initialize user entry if not present
    if (-not $userLoginDurations.ContainsKey($username)) {
        $userLoginDurations[$username] = New-Object System.Collections.ArrayList
    }

    # Store logon time
    $userLoginDurations[$username].Add(@($logonTime, 0)) | Out-Null # Store logon time and a placeholder for duration
}

# Process logoff events
foreach ($event in $logoffEvents) {
    $eventXml = [xml]$event.ToXml()
    $username = $eventXml.Event.EventData.Data | Where-Object {$_.Name -eq 'TargetUserName'} | Select-Object -ExpandProperty '#text'
    $logoffTime = $event.TimeCreated

    # Match logoff time to the last logon time for this user and calculate duration
    if ($userLoginDurations.ContainsKey($username) -and $userLoginDurations[$username].Count -gt 0) {
        $logonTime = $userLoginDurations[$username] | Where-Object {$_[1] -eq 0} | Select-Object -Last 1
        if ($null -ne $logonTime) {
            $duration = $logoffTime - $logonTime[0]
            $logonTime[1] = $duration.TotalHours # Update placeholder with actual duration
        }
    }
}

# Calculate total duration for each user
$userTotalDurations = @{}
foreach ($user in $userLoginDurations.Keys) {
    $totalDuration = ($userLoginDurations[$user] | ForEach-Object {$_[1]} | Measure-Object -Sum).Sum
    $userTotalDurations[$user] = $totalDuration
}

# Find the user with the maximum total duration
$maxDurationUser = $userTotalDurations.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1

# Output the result
Write-Output "User with the most logged in time: $($maxDurationUser.Key) with $($maxDurationUser.Value) hours"
