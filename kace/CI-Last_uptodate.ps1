$file = Get-Content -Path "C:\ProgramData\Quest\KACE\user\odrive3.txt"
$latestDate = $null

foreach ($line in $file) {
    if ($line -match "^(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Synced$") {
        $date = [datetime]::ParseExact($Matches[1], "MM/dd/yyyy HH:mm:ss", $null)
        if ($null -eq $latestDate -or $date -gt $latestDate) {
            $latestDate = $date
        }
    }
}

Write-Output "$latestDate"