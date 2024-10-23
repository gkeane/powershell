Unblock-File C:\ProgramData\Quest\KACE\user\OneDriveLib.dll 
Import-Module C:\ProgramData\Quest\KACE\user\OneDriveLib.dll 
Write-Output "Run Date: $(Get-Date)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt 
(Get-Content "C:\programdata\quest\kace\user\odrive3.txt") -replace "`0", "" | Set-Content "C:\programdata\quest\kace\user\odrive3.txt"
(gc c:\programdata\quest\kace\user\odrive3.txt) | ? {$_.trim() -ne "" } | set-content c:\programdata\quest\kace\user\odrive3.txt
[array]$ODStatusArray = Get-ODStatus -type Business1
$ODStatusIndex = 1
if ($ODStatusArray)
{
    ForEach ($ODStatus in $ODStatusArray)
    {
        Write-Output  "Status $ODStatusIndex :" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> LocalPath $ODStatusIndex = $($ODStatus.LocalPath)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> StatusString $ODStatusIndex = $($ODStatus.StatusString)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        Write-Output  "> DisplayName $ODStatusIndex = $($ODStatus.DisplayName)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt -Append
        if ($($env:OneDrive) -eq $($ODStatus.LocalPath))
        {
            Write-Output "$(Get-Date): $($ODStatus.StatusString)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive3.txt -Append -Encoding UTF8
            Write-Output "Run Date: $(Get-Date)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt 
            Write-Output  "Status $ODStatusIndex :" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "LocalPath : $($ODStatus.LocalPath)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "StatusString : $($ODStatus.StatusString)" | out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
            Write-Output  "DisplayName : $($ODStatus.DisplayName)"| out-file  -FilePath C:\ProgramData\Quest\KACE\user\odrive2.txt -Append
        }
        $ODStatusIndex++
    }
}