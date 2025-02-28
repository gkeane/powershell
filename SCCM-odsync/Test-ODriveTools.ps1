# Configuration
$ToolsPath = "C:\SCCMTools"
$RequiredFiles = @(
    "ODSyncUtil.exe",
    "ODSyncLib.dll"
)

# Check if tools directory exists
if (-not (Test-Path $ToolsPath)) {
    Write-Host "Tools directory not found: $ToolsPath"
    $false
    exit
}

# Check for required files
$allFilesPresent = $true
foreach ($file in $RequiredFiles) {
    $filePath = Join-Path $ToolsPath $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Missing required file: $file"
        $allFilesPresent = $false
        break
    }
}

# Return compliance state
$allFilesPresent 