$LogFile = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties" -Name "Local SMS Path").'Local SMS Path' + "Logs\CM_JavaUsageLogging.log"
$LoggingEnable = $True
$UTLogFileName = ".java_usage_cm"
$JsonFilePath = "C:\ProgramData\Quest\KACE\user\java_usage.json"  # Path to save the JSON file

########################################################################################################## 

Function Log-ScriptEvent { 
    [CmdletBinding()] 
    Param( 
          [parameter(Mandatory=$True)] 
          [String]$Value, 
          [parameter(Mandatory=$True)] 
          [ValidateRange(1,3)] 
          [Single]$Severity 
    ) 

    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime  
    $DateTime.SetVarDate($(Get-Date)) 
    $UtcValue = $DateTime.Value 
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21) 

    $LogLine =  "<![LOG[$Value]LOG]!>" +` 
                "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " +` 
                "date=`"$(Get-Date -Format M-d-yyyy)`" " +` 
                "component=`"Java Compliance`" " +`  
                "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +` 
                "type=`"$Severity`" " +` 
                "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +` 
                "file=`"`">" 

    Add-Content -Path $LogFile -Value $LogLine 
}

Function Create-UsageTrackingProps { 
    [CmdletBinding()] 
    Param( 
        [parameter(Mandatory=$True)] 
        [String]$UTPath
    ) 
    process {
        $utprops=@'
# UsageTracker template properties file.
com.oracle.usagetracker.logToFile = ${user.home}/.java_usage_cm
com.oracle.usagetracker.logFileMaxSize = 10000000
com.oracle.usagetracker.separator = ^
com.oracle.usagetracker.innerQuote = '
com.oracle.usagetracker.quote = " 
'@

        $utprops | Out-File -Encoding "UTF8" $UTPath
    }
}

########################################################################################################## 

IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Starting Java logging discovery." -Severity 1}

#Set Variables
$header = "Type","DateTime","HostIP","Command","JREPath","JavaVer","JREVer","JavaVen","JVMVen","OS","Arch","OSVer","JVMArg","ClassPath"
$DataSet = @()
$JREPaths = @("C:\Program Files (x86)\Java\jre7")

#Enable Java logging by enumerating the JREs from the registry
$Keys = Get-ChildItem "HKLM:\Software\WOW6432Node\JavaSoft\Java Runtime Environment"
$JREs = $Keys | Foreach-Object {Get-ItemProperty $_.PsPath }
ForEach ($JRE in $JREs) {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Interogating JRE path $($JRE.JavaHome)" -Severity 1}
    $JREPath = test-path "$($JRE.JavaHome)\lib\management"
    if ($JREPath) {
        $UTProps = test-path "$($JRE.JavaHome)\lib\management\usagetracker.properties"
        if (-Not $UTProps) {
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Creating $($JRE.JavaHome)\lib\management\usagetracker.properties" -Severity 1}
            Create-UsageTrackingProps -UTPath "$($JRE.JavaHome)\lib\management\usagetracker.properties"
        } Else {
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "$($JRE.JavaHome)\lib\management\usagetracker.properties exists" -Severity 1}
        }
    }
}

#Enumerate user profile folders from WMI
Try {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Gather user profile paths." -Severity 1}
    $users= gwmi win32_userprofile | select LocalPath
} Catch {
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Error gathering user profile paths." -Severity 3}
    Exit 5150
}

#Check each returned folder for a Java usage log and collect data.
Foreach ($user in $users) {
    Write-Host ($($user.LocalPath) -split '\\')[-1].ToString()
    IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Checking for $($user.LocalPath)\$($UTLogFileName)" -Severity 1}
    $path = test-path "$($user.LocalPath)\$($UTLogFileName)"
    
    if ($path) {
        IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Found $($user.LocalPath)\$($UTLogFileName), attempting to load data." -Severity 1}
        Try {
            $Data = import-csv "$($user.LocalPath)\$($UTLogFileName)" -Delimiter '^' -Header $header
            $DataSet += $Data | Select @{Name="User";Expression={($($user.LocalPath) -split '\\')[-1].ToString()}},Type,DateTime,HostIP,@{Name="Command";Expression={if($_.Command -like 'http*'){($_.Command -split ': ')[0].ToString() } else {($_.Command -split ':')[0]}}},JREPath,JavaVer,JREVer,JavaVen,JVMVen
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Parsing $($user.LocalPath)\$($UTLogFileName)" -Severity 1}
        } Catch {
            Write-Host "Error occurred" 
            IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Error parsing $($user.LocalPath)\$($UTLogFileName)" -Severity 3}
            Exit 5150
        }
    }
}

IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Completed data discovery, writing data to JSON file" -Severity 1}

# Write the dataset to a JSON file
$DataSet | ConvertTo-Json | Out-File -FilePath $JsonFilePath -Encoding UTF8

IF ($LoggingEnable -eq $true) {Log-ScriptEvent -Value "Data successfully written to JSON file" -Severity 1}
