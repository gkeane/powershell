$RegUninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

Write-Host "Starting Java uninstallation process..." -ForegroundColor Cyan

# Set up logging paths
$LogPath = "$env:windir\Logs\Software"
$LogFile = "JavaUninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$MsiLogPath = "$LogPath\MSI"
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $MsiLogPath)) {
    New-Item -Path $MsiLogPath -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $LogMessage
    Add-Content -Path "$LogPath\$LogFile" -Value $LogMessage
}

# Function to handle MSI uninstallation with logging
function Invoke-MsiUninstall {
    param (
        $ProductCode,
        $DisplayName
    )
    
    $msiLogFile = Join-Path $MsiLogPath "JavaUninstall_$($ProductCode.Replace('{','').Replace('}',''))_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Write-Log "MSI log will be written to: $msiLogFile"
    
    $process = Start-Process "msiexec.exe" -ArgumentList "/x $ProductCode /qn /l*v `"$msiLogFile`"" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Log "Successfully uninstalled: $DisplayName"
    } else {
        Write-Log "Failed to uninstall: $DisplayName (Exit code: $($process.ExitCode))"
    }

    # Read and append MSI log content if it exists
    if (Test-Path $msiLogFile) {
        Write-Log "=== MSI Log Content for $DisplayName ==="
        Get-Content $msiLogFile | ForEach-Object {
            # Filter for important MSI log entries
            if ($_ -match "Error|Warning|Info.*:|Return Value|Action start|Action ended") {
                Write-Log "MSI: $_"
            }
        }
        Write-Log "=== End MSI Log Content ==="
    } else {
        Write-Log "Warning: MSI log file was not created"
    }
    
    return $process.ExitCode
}

# Stop any running Java processes
Write-Host "Stopping Java processes..." -ForegroundColor Yellow
Get-CimInstance -ClassName 'Win32_Process' | Where-Object {$_.ExecutablePath -like '*Program Files\Java*'} | 
    Select-Object @{n='Name';e={$_.Name.Split('.')[0]}} | ForEach-Object {
        Write-Host "Stopping process: $($_.Name)" -ForegroundColor Gray
        Stop-Process -Force
    }
 
Write-Host "Stopping Internet Explorer processes..." -ForegroundColor Yellow
Get-process -Name *iexplore* | Stop-Process -Force -ErrorAction SilentlyContinue

# Use Win32reg_AddRemovePrograms to find Java installations
Write-Host "`nScanning for Java installations using registry and WMI..." -ForegroundColor Yellow
$foundVersions = 0

# Method 1: Using Win32reg_AddRemovePrograms
Get-CimInstance -ClassName 'Win32reg_AddRemovePrograms' | 
Where-Object { 
    ($_.DisplayName -like '*Java*' -or $_.DisplayName -like '*JDK*') -and 
    ($_.Publisher -eq 'Oracle Corporation' -or $_.Publisher -eq 'Sun Microsystems, Inc.')
} | ForEach-Object {
    $foundVersions++
    $displayName = $_.DisplayName
    $uninstallString = $_.UninstallString
    
    $productCode = if ($uninstallString -match "{[0-9A-F-]+}") { 
        $matches[0] 
    } elseif ($_.ProdID) {
        $_.ProdID
    }
    
    if ($productCode) {
        Write-Log "`nFound Java installation (WMI):"
        Write-Log "  Name: $displayName"
        Write-Log "  Product Code: $productCode"
        Write-Log "Uninstalling..."
        
        Invoke-MsiUninstall -ProductCode $productCode -DisplayName $displayName
    }
}

# Method 2: Direct Registry Scan
$RegPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($RegPath in $RegPaths) {
    if (Test-Path $RegPath) {
        Get-ChildItem $RegPath | 
        Where-Object { 
            ($_.GetValue('DisplayName') -like '*Java*' -or $_.GetValue('DisplayName') -like '*JDK*') -and
            ($_.GetValue('Publisher') -eq 'Oracle Corporation' -or $_.GetValue('Publisher') -eq 'Sun Microsystems, Inc.')
        } | ForEach-Object {
            $foundVersions++
            $displayName = $_.GetValue('DisplayName')
            $uninstallString = $_.GetValue('UninstallString')
            $productCode = if ($uninstallString -match "{[0-9A-F-]+}") { 
                $matches[0] 
            } else { 
                $_.PSChildName 
            }
            
            Write-Log "`nFound Java installation (Registry):"
            Write-Log "  Name: $displayName"
            Write-Log "  Product Code: $productCode"
            Write-Log "Uninstalling..."
            
            Invoke-MsiUninstall -ProductCode $productCode -DisplayName $displayName
        }
    }
}

if ($foundVersions -eq 0) {
    Write-Host "No Java installations found." -ForegroundColor Yellow
}

# Enhanced Java 8 check using both methods
Write-Host "`nChecking for Java 8 installations..." -ForegroundColor Yellow

# Method 1: WMI Check for Java 8
Get-CimInstance -ClassName 'Win32reg_AddRemovePrograms' | 
Where-Object { $_.DisplayName -like '*Java 8*' } | 
ForEach-Object {
    $displayName = $_.DisplayName
    $productCode = if ($_.UninstallString -match "{[0-9A-F-]+}") { 
        $matches[0] 
    } elseif ($_.ProdID) {
        $_.ProdID
    }
    
    if ($productCode) {
        Write-Host "Found Java 8 installation: $displayName" -ForegroundColor White
        Write-Host "Uninstalling..." -ForegroundColor Green
        
        $process = Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "Successfully uninstalled: $displayName" -ForegroundColor Green
        } else {
            Write-Host "Failed to uninstall: $displayName (Exit code: $($process.ExitCode))" -ForegroundColor Red
        }
    }
}

# Method 2: Registry Check for Java 8
foreach ($RegPath in $RegPaths) {
    if (Test-Path $RegPath) {
        Get-ChildItem $RegPath | 
        Where-Object { $_.GetValue('DisplayName') -like '*Java 8*' } |
        ForEach-Object {
            $displayName = $_.GetValue('DisplayName')
            $productCode = $_.PSChildName
            
            Write-Host "Found Java 8 installation (Registry): $displayName" -ForegroundColor White
            Write-Host "Uninstalling..." -ForegroundColor Green
            
            $process = Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn" -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Host "Successfully uninstalled: $displayName" -ForegroundColor Green
            } else {
                Write-Host "Failed to uninstall: $displayName (Exit code: $($process.ExitCode))" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nAttempting targeted Java GUID uninstallation..." -ForegroundColor Yellow

# Known Java GUID patterns
$javaGuidPatterns = @(
    '{26A24AE4-039D-4CA4-87B4-2F__180__F_}',
    '{71_24AE4-039E-4CA4-87B4-2F64180__1F0}',
    '{71_24AE4-039E-4CA4-87B4-2F32180__1F0}',
    '{26A24AE4-039D-4CA4-87B4-2F__180___F_}',  # For versions above 99
    '{77924AE4-039E-4CA4-87B4-2F32180411F0}'   # Additional specific pattern
)

# Add a more generic pattern match for Java-related GUIDs
$additionalPatterns = @(
    '{[0-9A-F]24AE4-039[DE]-4CA4-87B4-2F.*}'   # More generic pattern to catch variants
)

foreach ($pattern in ($javaGuidPatterns + $additionalPatterns)) {
    Write-Log "Searching for Java installations matching pattern: $pattern"
    try {
        $products = Get-WmiObject -Class Win32reg_AddRemovePrograms | 
            Where-Object { 
                $_.ProdID -match $pattern -or 
                $_.UninstallString -match $pattern
            }
        
        foreach ($product in $products) {
            $productCode = if ($product.UninstallString -match "{[0-9A-F-]+}") {
                $matches[0]
            } else {
                $product.ProdID
            }
            
            Write-Log "Found Java installation: $($product.DisplayName) ($productCode)"
            Write-Log "Uninstalling..."
            
            Invoke-MsiUninstall -ProductCode $productCode -DisplayName $product.DisplayName
        }
    } catch {
        Write-Log "Error processing GUID pattern $pattern : $_"
    }
}

Write-Host "`nCleaning up registry entries..." -ForegroundColor Yellow

# Clean up Add/Remove Programs entries
$UninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

foreach ($Path in $UninstallPaths) {
    if (Test-Path $Path) {
        Write-Log "Checking for orphaned Java entries in: $Path"
        Get-ChildItem $Path | 
        Where-Object { 
            ($_.GetValue('DisplayName') -like '*Java*') -and
            (-not (Test-Path ($_.GetValue('InstallLocation') + 'bin\java.exe') -ErrorAction SilentlyContinue))
        } | ForEach-Object {
            $displayName = $_.GetValue('DisplayName')
            Write-Log "Removing orphaned Add/Remove Programs entry: $displayName"
            Remove-Item $_.PSPath -Force -Recurse -ErrorAction SilentlyContinue
            if ($?) {
                Write-Log "Successfully removed entry: $displayName"
            } else {
                Write-Log "Failed to remove entry: $displayName"
            }
        }
    }
}

# Clean up Classes Root entries
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
$ClassesRootPath = "HKCR:\Installer\Products"
Get-ChildItem $ClassesRootPath | 
    Where-Object { ($_.GetValue('ProductName') -like '*Java*')} | ForEach-Object {
        $productName = $_.GetValue('ProductName')
        Write-Log "Removing Classes Root registry entry for: $productName"
        Remove-Item $_.PsPath -Force -Recurse
    }

# Clean up JavaSoft keys
$JavaSoftPath = 'HKLM:\SOFTWARE\JavaSoft'
if (Test-Path $JavaSoftPath) {
    Write-Log "Removing JavaSoft registry key..."
    Remove-Item $JavaSoftPath -Force -Recurse
}

# Clean up WOW6432Node JavaSoft keys
$JavaSoftWowPath = 'HKLM:\SOFTWARE\WOW6432Node\JavaSoft'
if (Test-Path $JavaSoftWowPath) {
    Write-Log "Removing WOW6432Node JavaSoft registry key..."
    Remove-Item $JavaSoftWowPath -Force -Recurse
}
