﻿<#  GARY BLOK | GARYTOWN.COM | @gwblok
    #https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d
   
   This script checks EventViewer for status of Fix based on the information in the link above.
   If the event is found, then the Fix has been applied successfully.

   Checks for Status of SKUSiPolicy.P7b file which is added to the device with the May CU KB
   Checks EFI Partition for that file, if not found, copies it into the correct location

   Sets Registry Value based on the link information (Hex 0x10 or Decimal 16), which gets reset to 0 after restart.

   Once it sets the registry value, it triggers a CM Restart, to make sure everything gets applied.

   23.05.10 - Initial Release
   23.05.11 - Added File Hash Compare for SKUSiPolicy.P7b
   23.05.15 - Added check that if HASH of SKUSiPolicy.P7b matches in both locations, set compliance to compliant.  This prevents running remediation again when system event log roles over.
#>


$Remediate = $false  #True = Remediation Script | False = Detection/Discovery Script 
$UseCase = "ConfigMgr" #Intune or ConfigMgr
#Intune = Proactive Remediation Syntax
#ConfigMgr = Configuration Item Syntax


Function Restart-ComputerCM {
    if (Test-Path -Path "C:\windows\ccm\CcmRestart.exe"){

        $time = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootBy' -Value $time -PropertyType QWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'RebootValueInUTC' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'NotifyUI' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'HardReboot' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindowTime' -Value 0 -PropertyType QWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'OverrideRebootWindow' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'PreferredRebootWindowTypes' -Value @("4") -PropertyType MultiString -Force -ea SilentlyContinue;
        $Null = New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData' -Name 'GraceSeconds' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;

        $CCMRestart = start-process -FilePath C:\windows\ccm\CcmRestart.exe -NoNewWindow -PassThru
    }
    else {
        Write-Output "No CM Client Found"
    }
}


$Compliance = "Non-Compliant"
$SKUSiPolicyPath = "$env:windir\System32\SecureBootUpdates\SKUSiPolicy.P7b"



#Test if Event logs has the ID for having applied the Remediation.   This only works for so long after remediation has run, as the eveng log will roll over and the data will go missing.
$DBXUpdateSuccess = Get-EventLog -LogName System -Source "Microsoft-Windows-TPM-WMI" -InstanceId 1035 -ErrorAction SilentlyContinue
if ($DBXUpdateSuccess){
    #Write-Output  "Patch has been Applied Successfully"
    $Compliance = "Compliant"
}

#Test if $env:windir\System32\SecureBootUpdates\SKUSiPolicy.P7b exists, it will only exist after the May update has been applied.
if (Test-Path -Path $SKUSiPolicyPath){
    $SKUSiPolicyHash = (Get-FileHash -Path $SKUSiPolicyPath).Hash
    $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
    $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
    $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
    $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
    if (Test-Path -LiteralPath "$($SystemVolume.path)\EFI\Microsoft\Boot\SKUSiPolicy.P7b"){
        $SKUSiPolicyEFIHash = (Get-FileHash -LiteralPath "$($SystemVolume.path)\EFI\Microsoft\Boot\SKUSiPolicy.P7b").Hash
    }
}

#If $env:windir\System32\SecureBootUpdates\SKUSiPolicy.P7b Hash matches EFI\Microsoft\Boot\SKUSiPolicy.P7b Hash, set Compliance to Compliant
if ($SKUSiPolicyEFIHash){
    if ($SKUSiPolicyHash -eq $SKUSiPolicyEFIHash){
        $Compliance = "Compliant"
    }
}
 
if ($Remediate -eq $true -and $Compliance -ne "Compliant"){
    Write-Output  "Patch has not been completely applied according to Event Logs"

    if (Test-Path -Path $SKUSiPolicyPath){
        #Test for checking files:
        #Get-ChildItem -LiteralPath $SystemVolume.path -Recurse | Where-Object {$_.name -match "P7b"}
        if (!(Test-Path -LiteralPath "$($SystemVolume.path)\EFI\Microsoft\Boot\SKUSiPolicy.P7b")){
            Write-Output "Copying $SKUSiPolicyPath to $($SystemVolume.path)\EFI\Microsoft\Boot"
            Copy-Item -Path $SKUSiPolicyPath -Destination "$($SystemVolume.path)\EFI\Microsoft\Boot" -Verbose
        }
        else {
            $SKUSiPolicyEFIHash = (Get-FileHash -LiteralPath "$($SystemVolume.path)\EFI\Microsoft\Boot\SKUSiPolicy.P7b").Hash
            if ($SKUSiPolicyHash -eq $SKUSiPolicyEFIHash){
                Write-Output "SKUSiPolicy file already in place and HASH Matches, skipping Copy"
            }
            else {
                Write-Output "SKUSiPolicy file exist, but Hash does NOT match, overwriting"
                Copy-Item -Path $SKUSiPolicyPath -Destination "$($SystemVolume.path)\EFI\Microsoft\Boot" -Verbose -Force
            }
        }

        $AvailableUpdateStatus = Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot -Name AvailableUpdates
        if ($AvailableUpdateStatus -ne 16){
            #This will trigger the system to know to apply the update, I've done this multiple times and have no seen an issue running it more than once.
            #if the log in the event viewer roles over and the entry for success is going, triggering this will have the event viewer recreate the entry after next reboot.
            Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot -Name AvailableUpdates -Type DWord -Value 16 -Force | Out-Null
            #If CM, Restart using CM Function
            if ($UseCase -ne "Intune"){Restart-ComputerCM}
            #IF Intune, Create Restart with 8 hour delay
            else {
                $Process = "C:\windows\system32\shutdown.exe"
                $ShutdownArgs = '/r /f /t 28800 /c "Apply fix for CVE-2023-24932"'
                Start-Process $Process -ArgumentList $ShutdownArgs -NoNewWindow
            }
        }

    }
    else {
        Write-Output "SKUSiPolicy Patch Not available, make sure you've updated Windows to latest CU"
    }
}


$variableName = "KACE_INSTALL_DIR"
$variableValue = $null
$defaultValue = "C:\programdata\quest\KACE\user"

if (-not [Environment]::GetEnvironmentVariable($variableName, "User") -or [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variableName, "User"))) {
    [Environment]::SetEnvironmentVariable($variableName, $defaultValue, "User")
} else {
    $variableValue = [Environment]::GetEnvironmentVariable($variableName, "User")
}
$outputPath = Join-Path $variableValue "user\CVE-secboot.txt"
if (Test-Path $outputPath) {
    Remove-Item -Path $outputPath -Confirm
}
#If non-compliant return blank
if ($Compliance -ne "Compliant"){
    "Non-Compliant" | Out-File -FilePath $outputPath
    exit 1
}



exit 1
