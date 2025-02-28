# Configuration
$ToolsPath = "C:\SCCMTools"
$NetworkShare = "\\sccm3.anr.udel.edu\SCCMTools"  # Update this to your network share
$LogsPath = Join-Path $ToolsPath "Logs"
$RequiredFiles = @(
    "ODSyncUtil.exe",
    "ODSyncLib.dll"
)

# Log file paths
$ToolsLogFile = Join-Path $LogsPath "odrive_tools.log"

# Initialize log file
Write-Output "=== ODrive Tools Installation Started $(Get-Date) ===" | Out-File -FilePath $ToolsLogFile -Encoding UTF8

# Ensure tools directory exists
if (-not (Test-Path $ToolsPath)) {
    try {
        New-Item -ItemType Directory -Path $ToolsPath -Force | Out-Null
        Add-Content -Path $ToolsLogFile -Value "Created tools directory: $ToolsPath" -Encoding UTF8
    }
    catch {
        Add-Content -Path $ToolsLogFile -Value "Error creating tools directory: $($_.Exception.Message)" -Encoding UTF8
        return $false
    }
}

# Create and set permissions for Logs directory
if (-not (Test-Path $LogsPath)) {
    try {
        New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null
        
        # Get current ACL
        $acl = Get-Acl $LogsPath
        
        # Create rule for Users group (write, read, execute)
        $usersAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "Users",
            "Modify",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        
        # Add the new rule
        $acl.AddAccessRule($usersAccessRule)
        
        # Apply the new ACL
        Set-Acl $LogsPath $acl
        
    }
    catch {
        Write-Error "Error setting up logs directory: $($_.Exception.Message)"
        return $false
    }
}

# Download required files
$allFilesPresent = $true
foreach ($file in $RequiredFiles) {
    $sourcePath = Join-Path $NetworkShare $file
    $destPath = Join-Path $ToolsPath $file
    
    if (-not (Test-Path $destPath)) {
        try {
            Add-Content -Path $ToolsLogFile -Value "Copying $file from network share..." -Encoding UTF8
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Add-Content -Path $ToolsLogFile -Value "Successfully copied $file" -Encoding UTF8
        }
        catch {
            Add-Content -Path $ToolsLogFile -Value "Error copying ${file}: $($_.Exception.Message)" -Encoding UTF8
            $allFilesPresent = $false
        }
    }
}

# Return true if all files are present
return $allFilesPresent 