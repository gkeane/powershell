# Define the logfile path
$logFile = "$PWD\reset_wu.log"

# Function to write to the logfile
function Write-Log {
    param (
        [string]$message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    $logEntry | Out-File -FilePath $logFile -Append
}

# Function to stop a service, disable it, and kill the process if it doesn't stop
function Stop-ServiceAndKill {
    param (
        [string]$serviceName
    )

    Write-Log "Stopping and disabling service $serviceName..."
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 30

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service.Status -ne 'Stopped') {
        Write-Log "Service $serviceName did not stop. Killing the process..."
        $processes = Get-Process | Where-Object { $_.Name -like "$serviceName*" }
        foreach ($process in $processes) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

# Function to start a service and re-enable it
function Start-ServiceAndEnable {
    param (
        [string]$serviceName
    )

    Write-Log "Starting and enabling service $serviceName..."
    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction SilentlyContinue
}

# Define Windows Update services
$services = @("wuauserv", "bits", "cryptsvc")

# Stop, disable, and kill Windows Update services if necessary
foreach ($service in $services) {
    Stop-ServiceAndKill -serviceName $service
}

# Delete Software Distribution and Catroot2 folders
$folders = @("C:\Windows\SoftwareDistribution", "C:\Windows\System32\catroot2")
foreach ($folder in $folders) {
    if (Test-Path -Path $folder) {
        Write-Log "Deleting folder $folder..."
        Remove-Item -Path "$folder\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Reset Windows Update components
Write-Log "Resetting Windows Update components..."

# Re-register Windows Update DLLs
$wuauservDlls = @(
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll",
    "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll",
    "softpub.dll", "wintrust.dll", "dssenh.dll", "rsaenh.dll", "gpkcsp.dll", "sccbase.dll",
    "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll",
    "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
    "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
)

foreach ($dll in $wuauservDlls) {
    Write-Log "Registering $dll..."
    regsvr32.exe /s $dll
}

# Reset the BITS service and Windows Update service to their default security descriptors
sc.exe sdset bits D:'(A;;CCDCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
sc.exe sdset wuauserv D:'(A;;CCDCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'

# Re-enable and start Windows Update services
foreach ($service in $services) {
    Start-ServiceAndEnable -serviceName $service
}

# Reset the Windows Update components using the Windows Update Agent
Write-Log "Resetting Windows Update components using the Windows Update Agent..."
wuauclt.exe /resetauthorization /detectnow

Write-Log "Windows Update components reset completed."
