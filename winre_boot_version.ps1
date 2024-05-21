$MountDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "$([Guid]::NewGuid().Guid)_winre"
Write-Host "[CVE-2022-41099] Create mount directory: $MountDir"
$null = New-Item -Path $MountDir -ItemType Directory
$RealNtVersion = "starting"
Write-Host "[CVE-2022-41099] Mount RE..."
reagentc.exe /mountre /path $MountDir
$comp = "unknown"
if ($LASTEXITCODE -eq 0) {
    $TargetFile = Join-Path -Path $MountDir -ChildPath "\Windows\System32\bootmenuux.dll"
    Write-Host "[CVE-2022-41099] File to check: $TargetFile"
    $RealNtVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($TargetFile).ProductVersion
    Write-Host "[CVE-2022-41099] File version: $RealNtVersion"
    $VersionString = "$($RealNtVersion.Split('.')[0]).$($RealNtVersion.Split('.')[1])"
    $FileVersion = $($RealNtVersion.Split('.')[2])
    $FileRevision = $($RealNtVersion.Split('.')[3])
    if ($VersionString -eq "10.0") {
        $ExpectedRevision = 0
        switch ($FileVersion) {
            "10240" { Write-Host "[CVE-2022-41099] Windows 10, version 1507, file revision should be >= 19567."; $ExpectedRevision = 19567 }
            "14393" { Write-Host "[CVE-2022-41099] Windows 10, version 1607, file revision should be >= 5499."; $ExpectedRevision = 5499 }
            "17763" { Write-Host "[CVE-2022-41099] Windows 10, version 1809, file revision should be >= 3646."; $ExpectedRevision = 3646 }
            "19041" { Write-Host "[CVE-2022-41099] Windows 10, version 2004, file revision should be >= 2247."; $ExpectedRevision = 2247 }
            "22000" { Write-Host "[CVE-2022-41099] Windows 11, version 21H2, file revision should be >= 1215."; $ExpectedRevision = 1215 }
            "22621" { Write-Host "[CVE-2022-41099] Windows 11, version 22H2, file revision should be >= 815."; $ExpectedRevision = 815 }
            "22631" { Write-Host "[CVE-2022-41099] Windows 11, version 23H2, file revision should be >= 815."; $ExpectedRevision = 815 }
            default { Write-Host "[CVE-2022-41099] Unsupported OS." }
        }
        if ($ExpectedRevision -ne 0) {
            if ($FileRevision -lt $ExpectedRevision) { Write-Host "[CVE-2022-41099] WinRE is vulnerable." -ForegroundColor Red; $comp="vulnerable" }
            else { Write-Host "[CVE-2022-41099] WinRE is not vulnerable." -ForegroundColor Green; $comp="not vulnerable" }
        }
    }
    else {
        Write-Host "[CVE-2022-41099] Unsupported version: $VersionString" 
        $RealNtVersion= "unsupported version"
        $comp = "unsupported version"
    }
    Write-Host "[CVE-2022-41099] Unmount RE..."

    dism.exe /unmount-image /mountDir:$MountDir /discard
}
else {
    Write-Host "[CVE-2022-41099] Failed to mount WinRE."
    $RealNtVersion = "unable to mount"
    $comp = "unable to mount" 
}
Write-Host "[CVE-2022-41099] Remove mount directory."
Remove-Item -Path $MountDir

try {
    $RealNtVersion | Out-File -FilePath c:\Programdata\Quest\KACE\user\winre_bootver.txt
    $comp | Out-File -FilePath c:\Programdata\Quest\KACE\user\winre_boot_comp.txt
    Write-Host "wrote out file"
    }
    catch {
        Write-Host "failed to file"
    }