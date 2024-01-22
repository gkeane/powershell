#Get current WinRE .wim location
$winre_loc = (c:\windows\system32\reagentc /info | findstr '\\?\GLOBALROOT\device').replace('Windows RE location: ', '').TRIM()

#Get current WinRE build version
$temp = (Dism /Get-ImageInfo /ImageFile:$winre_loc\winre.wim /index:1).Split([System.Environment]::NewLine)

foreach ($line in $temp){
    if ($line -match "Version :"){
    $winre_major_ver = $line.Split()[2]
    } else {
    if ($line -match "ServicePack Build :"){
    $winre_minor_ver = $line.Split()[3]
    }
    }
}
if ($winre_major_ver -ne $null) {
    $winre_ver = [Version]($winre_major_ver + "." + $winre_minor_ver)
    write-output $winre_ver
    $out = $winre_ver.tostring()
} else {
    #dunno, didn't run right. maybe no re partition
    write-output 0.0
    $out = 0.0
}
try {
    $out | Out-File -FilePath c:\Programdata\Quest\KACE\user\winre_version.txt
    Write-Host "wrote out json"
    }
    catch {
        Write-Host "failed to write json"
    }