# ── SETTINGS ─────────────────────────────────────────────────────────────────
$PollSeconds = 15
$LogFile     = "$env:SystemDrive\FeatureUpdateInstall_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date)

function Log {
    param([string]$Msg,[ValidateSet('INFO','WARN','ERROR')][string]$Lvl='INFO')
    $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'),$Lvl,$Msg
    Write-Host $line; Add-Content -LiteralPath $LogFile -Value $line
}

Log '=== Feature-Update installer starting ==='

try {
    # ── WUA objects ──────────────────────────────────────────────────────────
    $session   = New-Object -ComObject Microsoft.Update.Session
    $searcher  = $session.CreateUpdateSearcher()
    $installer = $session.CreateUpdateInstaller()

    Log 'Searching WSUS catalogue …'
    $sr = $searcher.Search("IsInstalled=0 AND IsHidden=0 AND Type='Software'")
    Log "Needed software updates: $($sr.Updates.Count)"
    foreach($u in $sr.Updates){Log "  • $($u.Title)"}

    # newest Feature Update
    $regex   = 'Feature update to Windows 1[01]|Windows 11, version'
    $feature = @(
        $sr.Updates |
        Where-Object { $_.Title -match $regex } |
        Sort-Object  LastDeploymentChangeTime -Descending
    )
    Log "Feature-update candidates: $($feature.Count)"
    if(!$feature){Log 'No Feature Update detected – exiting.' 'WARN';return}

    $upd = $feature[0]
    Log "Chosen update:`n  Title : $($upd.Title)`n  ID    : $($upd.Identity.UpdateID)"

    # accept EULA
    if(-not $upd.EulaAccepted){ Log 'Accepting EULA …'; $upd.AcceptEula() }

    # ── DOWNLOAD if needed ───────────────────────────────────────────────────
    if(-not $upd.IsDownloaded){
        Log 'Downloading payload …'
        $collD = New-Object -ComObject Microsoft.Update.UpdateColl
        [void]$collD.Add($upd)
        $dl    = $session.CreateUpdateDownloader()
        $dl.Updates = $collD

        # async download so we can poll %
        try{
            $dlJob = $dl.BeginDownload($null,$null)
            do{
                Start-Sleep $PollSeconds
                $dp = $dlJob.GetProgress()
                Log ("Download: {0,3}%  ({1}/{2} files)" -f `
                     $dp.PercentComplete,$dp.CurrentUpdateIndex+1,$dp.Updates.Count)
            }until($dlJob.IsCompleted)
            $dlRes = $dl.EndDownload($dlJob)
        }catch{
            $dlRes = $dl.Download()   # sync fallback
        }

        $dlTxt = switch($dlRes.ResultCode){
                    2{'Succeeded'} 3{'Succeeded w/ reboot'}4{'Failed'}5{'Aborted'}
                    default{"Unknown ($($dlRes.ResultCode))"}}
        Log "Download result: $dlTxt"
        if($dlRes.ResultCode -ne 2){
            Log 'Download failed – aborting install.' 'ERROR';return
        }
    }else{
        Log 'Payload already downloaded.'
    }

    # ── INSTALL ──────────────────────────────────────────────────────────────
    $collI = New-Object -ComObject Microsoft.Update.UpdateColl
    [void]$collI.Add($upd)
    $installer.Updates    = $collI
    $installer.ForceQuiet = $true

    Log 'Beginning install …'
    try{ $job = $installer.BeginInstall($null,$null) }catch{
        $hr='0x{0:X8}' -f ($_.Exception.HResult -band 0xFFFFFFFF)
        Log "BeginInstall() failed – $hr  $_" 'WARN'; $job=$null
    }

    if($job){
        do{
            Start-Sleep $PollSeconds
            $ip = $job.GetProgress()
            Log ("Install: {0,3}%  (update {1}/{2})" -f `
                 $ip.PercentComplete,$ip.CurrentUpdateIndex+1,$collI.Count)
        }until($job.IsCompleted)
        $res = $installer.EndInstall($job)
    }else{
        Log 'Falling back to synchronous Install() …' 'WARN'
        $res = $installer.Install()
    }

    # ── RESULTS ──────────────────────────────────────────────────────────────
    $resTxt=switch($res.ResultCode){
        2{'Succeeded'}3{'Succeeded – reboot required'}4{'Failed'}5{'Aborted'}
        default{"Unknown ($($res.ResultCode))"}}
    Log '==== INSTALL FINISHED ===='
    Log "Overall : $resTxt"
    Log ('HResult : 0x{0:X8}' -f ($res.HResult -band 0xFFFFFFFF))
    Log "Reboot? : $($res.RebootRequired)"

    # per-update detail
    for($i=0;$i -lt $res.Updates.Count;$i++){
        $u=$res.Updates.Item($i);$ur=$res.GetUpdateResult($i)
        $rt=switch($ur.ResultCode){
            2{'OK'}3{'OK (reboot)'}4{'FAIL'}5{'ABORT'} default{"$($ur.ResultCode)"}
        }
        Log ("· {0}`n    Result  : {1}`n    HResult : 0x{2:X8}" -f `
              $u.Title,$rt,($ur.HResult -band 0xFFFFFFFF))
    }

    if($res.RebootRequired){
        Log 'Reboot in 60 s …' 'WARN'
        shutdown.exe /r /t 60 /c "Feature Update installed – automatic reboot"
    }
}
catch{
    Log "Unhandled: $($_.Exception.Message)" 'ERROR'
    Log "Stack   : $($_.Exception.StackTrace)" 'ERROR'
}
finally{
    Log "Log saved to $LogFile"
}
