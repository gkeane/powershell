$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"


Write-Host "Starting System File Checker..." -ForegroundColor Green

# Run System File Checker
Write-Host "`nRunning System File Checker..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$sfcResult = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
if ($sfcResult.ExitCode -eq 0) {
    Write-Host "SFC completed successfully" -ForegroundColor Green
} else {
    Write-Host "SFC encountered some issues. Exit code: $($sfcResult.ExitCode)" -ForegroundColor Red
}

Write-Host "`nSystem File Checker completed." -ForegroundColor Green 