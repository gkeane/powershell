# Define path to Java installations log
$logPath = "C:\ProgramData\Quest\KACE\user\java_installations.log"

# Check if file exists
if (Test-Path $logPath) {
    # Read and return the content
    $content = Get-Content $logPath -Raw
    if ($content) {
        Write-Output $content
    } else {
        Write-Output "NO_JAVA_FOUND"
    }
} else {
    Write-Output "LOG_NOT_FOUND"
} 