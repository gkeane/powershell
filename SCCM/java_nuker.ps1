<#
.SYNOPSIS
    Java Runtime Nuker - Removes all versions of Java Runtime Environment
.DESCRIPTION
    1. Nuke ALL versions of JavaFX and the Java Runtime, series 3 through 11, x86 and x64
    2. Leaves Java Development Kit installations intact
    3. Puts the lotion on its skin
.NOTES
    Original Author: reddit.com/user/vocatus
    PowerShell Version: 1.0.0
#>

# Variables
$LogPath = "$env:windir\CCM\Logs"
$LogFile = "$env:COMPUTERNAME`_java_runtime_removal.log"
$ForceCloseProcesses = $true

# Create log directory if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path "$LogPath\$LogFile" -Value $logMessage
}

Write-Log "Java Runtime Nuker starting..."

# Force close processes if enabled
if ($ForceCloseProcesses) {
    Write-Log "Closing Java-related processes..."
    $processesToKill = @('java', 'javaw', 'javaws', 'jqs', 'jusched', 'jp2launcher', 
                        'iexplore', 'iexplorer', 'firefox', 'chrome', 'palemoon', 'opera')
    foreach ($proc in $processesToKill) {
        Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

# WMI Uninstallation section
Write-Log "Starting WMI uninstallation..."

# JRE 11
Write-Log "Removing JRE 11..."
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like 'Java 11*' } | 
    ForEach-Object { $_.Uninstall() }

# JRE 10
Write-Log "Removing JRE 10..."
Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.IdentifyingNumber -like '{EECB2736-D013-5AC5-9917-7656712F6931}' 
} | ForEach-Object { $_.Uninstall() }

# JRE 9
Write-Log "Removing JRE 9..."
$JRE9GUIDs = @(
    '{DA69628A-2608-5BA9-8749-1EE90CB29D95}',
    '{2590B9D6-4310-52BC-808E-1A585861A836}',
    '{885A3911-0760-5252-92C2-001B92997DEA}'
)
foreach ($guid in $JRE9GUIDs) {
    Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.IdentifyingNumber -like $guid 
    } | ForEach-Object { $_.Uninstall() }
}

# JRE 8
Write-Log "Removing JRE 8..."
$JRE8Patterns = @(
    '{26A24AE4-039D-4CA4-87B4-2F8__180__F_}',
    '{71_24AE4-039E-4CA4-87B4-2F64180__1F0}',
    '{71_24AE4-039E-4CA4-87B4-2F32180__1F0}',
    '{26A24AE4-039D-4CA4-87B4-2F__180___F_}'
)
foreach ($pattern in $JRE8Patterns) {
    Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.IdentifyingNumber -like $pattern 
    } | ForEach-Object { $_.Uninstall() }
}

# JRE 7
Write-Log "Removing JRE 7..."
Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.IdentifyingNumber -like '{26A24AE4-039D-4CA4-87B4-2F___170__FF}' 
} | ForEach-Object { $_.Uninstall() }

# JRE 6
Write-Log "Removing JRE 6..."
Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.IdentifyingNumber -like '{26A24AE4-039D-4CA4-87B4-2F8__160__FF}' -or
    $_.IdentifyingNumber -like '{3248F0A8-6813-11D6-A77B-00B0D0160__0}' 
} | ForEach-Object { $_.Uninstall() }

# Cleanup section
Write-Log "Starting cleanup..."

# Remove Java services
$services = @('JavaQuickStarterService', 'jusched')
foreach ($service in $services) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Stop-Service -Name $service -Force
        sc.exe delete $service
    }
}

# Remove Java directories
$javaDirectories = @(
    "$env:ProgramFiles\Java",
    "${env:ProgramFiles(x86)}\Java",
    "$env:ProgramFiles\JavaSoft",
    "${env:ProgramFiles(x86)}\JavaSoft",
    "$env:ProgramFiles\Common Files\Oracle\Java",
    "${env:ProgramFiles(x86)}\Common Files\Oracle\Java",
    "$env:ProgramData\Oracle\Java",
    "$env:CommonProgramFiles\Java\Java Update",
    "${env:CommonProgramFiles(x86)}\Java\Java Update"
)

foreach ($dir in $javaDirectories) {
    if (Test-Path $dir) {
        Write-Log "Removing directory: $dir"
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove Java binaries from Windows system folders
$javaBinaries = @(
    "$env:SystemRoot\System32\java.exe",
    "$env:SystemRoot\System32\javaw.exe",
    "$env:SystemRoot\System32\javaws.exe",
    "$env:SystemRoot\SysWOW64\java.exe",
    "$env:SystemRoot\SysWOW64\javaw.exe",
    "$env:SystemRoot\SysWOW64\javaws.exe"
)

foreach ($binary in $javaBinaries) {
    if (Test-Path $binary) {
        Write-Log "Removing binary: $binary"
        Remove-Item -Path $binary -Force -ErrorAction SilentlyContinue
    }
}

# Registry cleanup
Write-Log "Cleaning registry..."

# Remove JavaSoft keys
$registryPaths = @(
    "HKLM:\SOFTWARE\JavaSoft",
    "HKLM:\SOFTWARE\Wow6432Node\JavaSoft",
    "HKLM:\SOFTWARE\JreMetrics",
    "HKLM:\SOFTWARE\Wow6432Node\JreMetrics"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Write-Log "Removing registry key: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove Control Panel icons
$controlPanelKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{4299124F-F2C3-41b4-9C73-9236B2AD0E8F}",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\explorer\ControlPanelWOW64\NameSpace\{4299124F-F2C3-41b4-9C73-9236B2AD0E8F}"
)

foreach ($key in $controlPanelKeys) {
    if (Test-Path $key) {
        Write-Log "Removing Control Panel registry key: $key"
        Remove-Item -Path $key -Force -ErrorAction SilentlyContinue
    }
}

# Trigger SCCM Hardware Inventory
Write-Log "Triggering SCCM Hardware Inventory..."
try {
    $HardwareInventoryID = "{00000000-0000-0000-0000-000000000001}"
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule $HardwareInventoryID
    Write-Log "SCCM Hardware Inventory triggered successfully"
} catch {
    Write-Log "Failed to trigger SCCM Hardware Inventory: $_"
}

Write-Log "Java Runtime Nuker completed. Recommend rebooting the system."
