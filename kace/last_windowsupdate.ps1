# Get the last installed Windows Update with a security classification
$lastSecurityUpdate = Get-HotFix | Where-Object { $_.Description -like "*Update*" } | Sort-Object -Property InstalledOn -Descending | Select-Object -First 1

if ($lastSecurityUpdate) {
    $lastUpdateDate = $lastSecurityUpdate.InstalledOn
    Write-Host "$lastUpdateDate"
} else {
    Write-Host "No security updates found in the update history."
}