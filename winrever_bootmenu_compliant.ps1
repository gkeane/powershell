# Get the current WinRE .wim location
$patched_Win11_22H2 = [version]"10.0.22621.815"
$patched_Win11_23H2 = [version]"10.0.22631.2506"
$patched_Win11_21H2 = [version]"10.0.22000.1215"
$patched_Win10_22H2 = [version]"10.0.19045.2247"
$patched_Win10_21H2 = [version]"10.0.19044.2247"
$patched_Win10_20H2 = [version]"10.0.19042.2247"
$patched_Win10_20H1 = [version]"10.0.19041.2247"

$mountDir = "C:\WinREMount"
mkdir $mountDir -Force
reagentc /mountre /path $mountdir

# Get version info of bootmenuux.dll
$bootmenuuxPath = "$mountDir\Windows\System32\bootmenuux.dll"
if (Test-Path $bootmenuuxPath) {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($bootmenuuxPath)
    #Write-Host "bootmenuux.dll Version: $($versionInfo.ProductVersion)"
} else {
    #Write-Host "bootmenuux.dll not found"
}
$winre_major_ver = $versionInfo.ProductMajorPart.tostring() + "." + $versionInfo.ProductMinorPart.tostring() + "." + $versionInfo.ProductBuildPart.tostring() 
#write-host $winre_major_ver
$winre_ver = $versionInfo.ProductVersion
# Cleanup: Unmount the WinRE image
dism /unmount-wim /MountDir:$mountDir /discard
Remove-Item $mountDir -Recurse

switch ($winre_major_ver) {
   "10.0.22631"  {if ($winre_ver -lt $patched_Win11_23H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.22621"  {if ($winre_ver -lt $patched_Win11_22H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.22000"  {if ($winre_ver -lt $patched_Win11_21H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.19045"  {if ($winre_ver -lt $patched_Win10_22H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.19044"  {if ($winre_ver -lt $patched_Win10_21H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.19042"  {if ($winre_ver -lt $patched_Win10_20H2){return "Not Compliant"} else {return "Compliant"}; break}
   "10.0.19041"  {if ($winre_ver -lt $patched_Win10_20H1){return "Not Compliant"} else {return "Compliant"}; break}
}
