# Get the current WinRE .wim location

$mountDir = "C:\WinREMount"
mkdir $mountDir -Force
reagentc /mountre /path $mountdir

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