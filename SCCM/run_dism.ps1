# Requires administrator privileges
#Requires -RunAsAdministrator

# Set script timeout (2 hours)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
$MaximumTimeoutSeconds = 7200

# Increase .NET script timeout
if ($PSVersionTable.PSVersion.Major -ge 3) {
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $sessionState.ExecutionTimeLimit = [TimeSpan]::FromSeconds($MaximumTimeoutSeconds)
}

Write-Host "Starting DISM repair process..." -ForegroundColor Green

# Run DISM to repair Windows image
Write-Host "`nRunning DISM to check and repair Windows image..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$dismResult = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/RestoreHealth" -Wait -PassThru -NoNewWindow
if ($dismResult.ExitCode -eq 0) {
    Write-Host "DISM completed successfully" -ForegroundColor Green
} else {
    Write-Host "DISM encountered some issues. Exit code: $($dismResult.ExitCode)" -ForegroundColor Red
}

Write-Host "`nDISM repair process completed." -ForegroundColor Green 