Write-Output "Run Date: $(Get-Date)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt 
(Get-Content "C:\programdata\quest\kace\user\odrive3.txt") -replace "`0", "" | Set-Content "C:\programdata\quest\kace\user\odrive3.txt"
(Get-Content c:\programdata\quest\kace\user\odrive3.txt) | Where-Object {$_.trim() -ne "" } | Set-Content c:\programdata\quest\kace\user\odrive3.txt
$ODStatusArray = & "C:\programdata\quest\kace\user\ODSyncUtil.exe"| ConvertFrom-Json
$ODStatusIndex = 1
if ($ODStatusArray)
{
    ForEach ($ODStatus in $ODStatusArray)
    {
        Write-Output  "Status $ODStatusIndex :" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> FolderPath $ODStatusIndex = $($ODStatus.FolderPath)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> StatusString $ODStatusIndex = $($ODStatus.CurrentStatesString)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> CurrentState $ODStatusIndex = $($ODStatus.CurrentState)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> ServiceName $ODStatusIndex = $($ODStatus.ServiceName)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> UsedQuota $ODStatusIndex = $($ODStatus.UsedQuota)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> TotalQuota $ODStatusIndex = $($ODStatus.TotalQuota)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> QuotaLabel $ODStatusIndex = $($ODStatus.QuotaLabel)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        # if the OneDrive path is same as the one in the array, that means it's the users onedrive write to odrive2.txt
        if ($($env:OneDrive) -eq $($ODStatus.FolderPath))
        {
            Write-Output "$(Get-Date): $($ODStatus.CurrentStateString)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive3.txt -Append -Encoding UTF8
            Write-Output "Run Date: $(Get-Date)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt 
            Write-Output  "Status $ODStatusIndex :" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> FolderPath $ODStatusIndex = $($ODStatus.FolderPath)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> StatusString $ODStatusIndex = $($ODStatus.CurrentStateString)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> CurrentState $ODStatusIndex = $($ODStatus.CurrentState)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> ServiceName $ODStatusIndex = $($ODStatus.ServiceName)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> UsedQuota $ODStatusIndex = $($ODStatus.UsedQuota)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> TotalQuota $ODStatusIndex = $($ODStatus.TotalQuota)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "> QuotaLabel $ODStatusIndex = $($ODStatus.QuotaLabel)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
        }
        $ODStatusIndex++
    }
}

# Get OneDrive status and check for path match
try {
    $ODStatusArray = & "C:\programdata\quest\kace\user\ODSyncUtil.exe" | ConvertFrom-Json
    $pathMatch = $false
    
    if ($ODStatusArray) {
        foreach ($ODStatus in $ODStatusArray) {
            if ($env:OneDrive -eq $ODStatus.FolderPath) {
                $pathMatch = $true
                break
            }
        }
    }
    
    # Output just true or false to the file
    $pathMatch.ToString().ToLower() | Out-File -FilePath "C:\ProgramData\Quest\KACE\user\odrive_match.txt" -NoNewline
}
catch {
    "false" | Out-File -FilePath "C:\ProgramData\Quest\KACE\user\odrive_match.txt" -NoNewline
}

# Get last sync date from odrive3.txt
try {
    $file = Get-Content -Path "C:\ProgramData\Quest\KACE\user\odrive3.txt"
    $latestDate = $null

    foreach ($line in $file) {
        if ($line -match "^(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced$") {
            $date = [datetime]::ParseExact($Matches[1], "MM/dd/yyyy HH:mm:ss", $null)
            if ($latestDate -eq $null -or $date -gt $latestDate) {
                $latestDate = $date
            }
        }
    }

    # If no sync date found, use Unix epoch
    if ($latestDate -eq $null) {
        $latestDate = [datetime]::ParseExact("01/01/1970 00:00:00", "MM/dd/yyyy HH:mm:ss", $null)
    }

    # Write last sync date to file
    $latestDate.ToString("MM/dd/yyyy HH:mm:ss") | Out-File -FilePath "C:\ProgramData\Quest\KACE\user\odrive_lastsync.txt" -NoNewline
}
catch {
    # If any error occurs, write Unix epoch as fallback
    "01/01/1970 00:00:00" | Out-File -FilePath "C:\ProgramData\Quest\KACE\user\odrive_lastsync.txt" -NoNewline
}