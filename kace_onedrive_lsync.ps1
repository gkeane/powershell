$path = "C:\ProgramData\Quest\KACE\user\odrive3.txt"
try {
    $file = Get-Content -Path $path
} catch { 
    Write-Host "File not found"
}
$latestDate = $null

foreach ($line in $file) {
    if ($line -match "^(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}): Up to date$") {
        $date = [datetime]::ParseExact($Matches[1], "MM/dd/yyyy HH:mm:ss", $null)
        if ($latestDate -eq $null -or $date -gt $latestDate) {
            $latestDate = $date
        }
    }
}
$file | Select-Object -Last 100 | Set-Content $path
if  ($latestDate -eq $null) {Write-Host "no data"}
else {Write-Host $latestDate}
