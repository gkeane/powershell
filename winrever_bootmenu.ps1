# Get the current WinRE .wim location
$winreInfo = reagentc /info | Out-String
$winrePath = ($winreInfo -match 'Windows RE location:\s*(\S+)') -replace 'Windows RE location:\s*', ''

# Mount the WinRE .wim file
$mountDir = "C:\WinREMount"
mkdir $mountDir -Force
dism /mount-wim /WimFile:"$winrePath\winre.wim" /index:1 /MountDir:$mountDir

# Get version info of bootmenuux.dll
$bootmenuuxPath = "$mountDir\Windows\System32\bootmenuux.dll"
if (Test-Path $bootmenuuxPath) {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($bootmenuuxPath)
    Write-Host "bootmenuux.dll Version: $($versionInfo.ProductVersion)"
} else {
    Write-Host "bootmenuux.dll not found"
}

# Cleanup: Unmount the WinRE image
dism /unmount-wim /MountDir:$mountDir /discard
Remove-Item $mountDir -Recurse