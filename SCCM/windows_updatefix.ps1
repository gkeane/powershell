# Requires administrator privileges
#Requires -RunAsAdministrator

# Set script timeout to 2 hours (7200 seconds)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
$MaximumTimeoutSeconds = 7200

# Increase .NET script timeout
if ($PSVersionTable.PSVersion.Major -ge 3) {
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $sessionState.ExecutionTimeLimit = [TimeSpan]::FromSeconds($MaximumTimeoutSeconds)
}

Write-Host "Starting Windows Update troubleshooting..." -ForegroundColor Green

# Stop Windows Update related services
$services = @(
    "wuauserv",          # Windows Update
    "cryptSvc",          # Cryptographic Services
    "bits",              # Background Intelligent Transfer Service
    "msiserver"          # Windows Installer
)

Write-Host "Stopping Windows Update services..." -ForegroundColor Yellow
foreach ($service in $services) {
    try {
        Stop-Service -Name $service -Force -ErrorAction Stop
        Write-Host "Stopped $service" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not stop $service service, attempting to kill process..." -ForegroundColor Yellow
        $processes = Get-Process | Where-Object {$_.Name -eq $service}
        if ($processes) {
            $processes | ForEach-Object { 
                Stop-Process -Id $_.Id -Force
            }
            Write-Host "Forcefully terminated $service processes" -ForegroundColor Yellow
        }
    }
}

# Delete Windows Update cache
Write-Host "Clearing Windows Update cache..." -ForegroundColor Yellow
$windowsUpdatePath = "$env:SystemRoot\SoftwareDistribution"
if (Test-Path $windowsUpdatePath) {
    Remove-Item -Path "$windowsUpdatePath\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# Reset Windows Update components
Write-Host "Resetting Windows Update components..." -ForegroundColor Yellow
$commands = @(
    "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)",
    "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
)

foreach ($command in $commands) {
    Invoke-Expression -Command $command
}

# Reset BITS and Windows Update service to default security descriptor
Write-Host "Registering Windows Update DLLs..." -ForegroundColor Yellow
$dlls = @(
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
    "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
    "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
    "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
    "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
    "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
    "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll",
    "wuwebv.dll"
)

foreach ($dll in $dlls) {
    if (Test-Path "$env:SystemRoot\System32\$dll") {
        regsvr32.exe /s "$env:SystemRoot\System32\$dll"
    }
}

# Start Windows Update services
Write-Host "Starting Windows Update services..." -ForegroundColor Yellow
foreach ($service in $services) {
    Start-Service -Name $service
    Write-Host "Started $service"
}

# Force Windows Update to check for updates
Write-Host "Forcing Windows Update check..." -ForegroundColor Yellow
wuauclt.exe /resetauthorization /detectnow

# Run DISM to repair Windows image
Write-Host "`nRunning DISM to check and repair Windows image..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$dismResult = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/RestoreHealth" -Wait -PassThru -NoNewWindow
if ($dismResult.ExitCode -eq 0) {
    Write-Host "DISM completed successfully" -ForegroundColor Green
} else {
    Write-Host "DISM encountered some issues. Exit code: $($dismResult.ExitCode)" -ForegroundColor Red
}

# Run System File Checker
Write-Host "`nRunning System File Checker..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$sfcResult = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
if ($sfcResult.ExitCode -eq 0) {
    Write-Host "SFC completed successfully" -ForegroundColor Green
} else {
    Write-Host "SFC encountered some issues. Exit code: $($sfcResult.ExitCode)" -ForegroundColor Red
}

Write-Host "`nWindows Update troubleshooting completed." -ForegroundColor Green
Write-Host "Please restart your computer and check for updates again." -ForegroundColor Yellow
