$file = Get-Content -Path "C:\ProgramData\Quest\KACE\user\odrive3.txt"
$latestDate = $null

foreach ($line in $file) {
    Write-Output $line
    if ($line -match "^(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced$") {
        $date = [datetime]::ParseExact($Matches[1], "MM/dd/yyyy HH:mm:ss", $null)
        if ($latestDate -eq $null -or $date -gt $latestDate) {
            $latestDate = $date
        }
    }
}

if ($latestDate -eq $null) {
    $latestDate = [datetime]::ParseExact("01/01/1970 00:00:00", "MM/dd/yyyy HH:mm:ss", $null)
}

Write-Output "$latestDate"