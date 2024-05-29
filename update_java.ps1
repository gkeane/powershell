### Upgrade Java Runtime Environment

<#
    Determine which version is currently installed

    If Java isn't installed, don't continue.
#>
$regKeys = @(
    'HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment\*\MSI'
    'HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Runtime Environment\*\MSI'
)

Foreach ($key in $regKeys)
{
    If (Test-Path $key)
    {
        $installedJreVersion = (Get-ItemProperty -Path $key).FullVersion
    }
}

If (-not ($installedJreVersion) )
{
    Write-Host 'Java is not installed'
    Break; Exit;
}


<#
    Get the currently installed architecture.
    This is needed to download the correction version of the installer.
#>
$javaProgramFiles = @(
    'C:\Program Files (x86)\Java\*\release'
    'C:\Program Files\Java\*\release'
)

Foreach ($jpf in $javaProgramFiles)
{
    If (Test-Path $jpf)
    {
        $javaRelease = (Get-Content $jpf) -replace '"' | ConvertFrom-StringData
        $javaVersion = $javaRelease.JAVA_VERSION
        $javaArch = $javaRelease.OS_ARCH
    }
}

<#
    Find the latest version of Java and retrieve the coresponding .xml

    When reading the xml, we need to filter out the customer builds. We can do this by selecting
    entries marked as 'critical' or by filtering entries that match '-cb'.
    
    You can filter out customer builds using this method -
    $target = [string]($mapXML.'java-update-map'.mapping.url | Where-Object {$_ -notmatch '\-cb\.xml'} | Select-Object -Last 1)
#>
$params = @{
    'Uri' = 'https://javadl-esd-secure.oracle.com/update/1.8.0/map-1.8.0.xml'
    'UserAgent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.85 Safari/537.36 Edg/90.0.818.46'
}
$mapXML = Invoke-RestMethod @params

# Select latest build from entries marked as 'critical'
$target = ($mapXML.'java-update-map'.mapping | Where-Object {$_.critical -eq 1} | Select-Object -Last 1)

$params = @{
    'Uri' = [string]$target.url
    'ContentType' = 'application/xml'
    'UserAgent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.85 Safari/537.36 Edg/90.0.818.46'
}
$javaXml = Invoke-RestMethod @params


<#
    Retrieve the exact build number from the xml.

    Create a direct link to the offline installer.
    We do this by substituting the 'au' (automatic update) value in the url with the desired architecture.
    e.g. jre-8u361-windows-au.exe becomes jre-8u361-windows-x64.exe
#>

$javaUpdateInfo = $javaXml.'java-update'.information
$availableJreVersion = ($javaUpdateInfo | Where-Object {$_.lang -eq 'en'}).version -notmatch '^1\.0$'
$javaUpdateUrl = [string]($javaUpdateInfo.url) -replace '\-au',"-${javaArch}"

<#
    Only continue if our installed version is out of date.
#>
If ($availableJreVersion -gt $installedJreVersion)
{
    Write-Host 'Installation out of date. Update Required'
    Write-Host "Upgrading ${installedJreVersion} >> ${availableJreVersion}"
    <#
        Specify where we will be saving the file - create the Path if it doesn't exist.
    #>
    $destPath = "${env:SystemDrive}\Temp"
    If (-not ( Test-Path $destPath ) )
    {
        [void](New-Item -ItemType 'Directory' -Path $destPath -Confirm:$false)
    }
    <#
        Get the original file name and define where to save it locally.
    #>
    $request = [System.Net.WebRequest]::Create($javaUpdateUrl).GetResponse()
    $fileName = [string]($request.ResponseUri.Segments | Select-Object -Last 1)
    $binPath = "${destPath}\${fileName}"

    <#
        Download the installer
    #>
    $params = @{
        'uri' = $javaUpdateUrl
        'outFile' = $binPath
        'userAgent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.85 Safari/537.36 Edg/90.0.818.46'
    }
    # Disable the WebRequest Progress bar so it goes faster
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest @params

    <#
        Create an installation config file for silent deployment.

        Specify our installation options per the official doc
        https://docs.oracle.com/javase/8/docs/technotes/guides/install/config.html#installing_with_config_file
    #>
    $configPath = "${destPath}\java.cfg"
    $javaConfig = @(
        'INSTALL_SILENT=1'
        'NOSTARTMENU=1'
        'REBOOT=0'
        'REMOVEOUTOFDATEJRES=1'
        'WEB_ANALYTICS=0'
        'WEB_JAVA_SECURITY_LEVEL=VH'
    )
    $javaConfig | Out-File -Encoding ascii -FilePath $configPath

    <#
        Run the installer with instruction to use the config
    #>

    $runBin = Start-Process -FilePath $binPath -ArgumentList "INSTALLCFG=${configPath}" -PassThru
    $runBin.WaitForExit()
}

If ($availableJreVersion -le $installedJreVersion)
{
    Write-Host 'Upgrade NOT required'
    Write-Host "Available Version: ${availableJreVersion}"
    Write-Host "Installed Version: ${installedJreVersion}"
}