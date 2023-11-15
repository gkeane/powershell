Unblock-File C:\ProgramData\Quest\KACE\user\OneDriveLib.dll 
Import-Module C:\ProgramData\Quest\KACE\user\OneDriveLib.dll 
Write-Output "Run Date: $(Get-Date)" | out-file -FilePath C:\ProgramData\Quest\KACE\user\odrive.txt 
$status = Get-ODStatus -Type Business1 
$debug2 = Get-Item -Path "$($env:OneDrive)*"
Write-Output "hello"
Write-Output $status[0]
Write-Output $status[0].GetType()