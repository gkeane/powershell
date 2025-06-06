# Deploy Reboot - Toast Configuration Item and Baseline
# This script creates a Configuration Item to monitor days since last reboot

# Import the ConfigMgr module and set the location to the site
try {
    # Check if ConfigurationManager module is available
    if (-not (Get-Module ConfigurationManager)) {
        Write-Host "Importing Configuration Manager module..." -ForegroundColor Yellow
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
    }

    # Get the site code
    $SiteCode = Get-PSDrive -PSProvider CMSITE -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Name
    if (-not $SiteCode) {
        Write-Host "No SCCM site found. Creating new PSDrive..." -ForegroundColor Yellow
        $ProviderMachineName = $env:COMPUTERNAME
        if (-not $ProviderMachineName) { throw "Unable to determine SCCM provider machine name" }
        
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName -ErrorAction Stop | Out-Null
    }

    # Change to the SCCM drive
    Write-Host "Connecting to SCCM site $SiteCode..." -ForegroundColor Yellow
    Push-Location
    Set-Location "$($SiteCode):" -ErrorAction Stop
    Write-Host "Successfully connected to SCCM site $SiteCode" -ForegroundColor Green
} catch {
    Write-Host "Error connecting to SCCM: $_" -ForegroundColor Red
    Write-Host "Make sure you're running this from a machine with the SCCM admin console installed" -ForegroundColor Yellow
    if ((Get-Location).Drive.Name -eq $SiteCode) {
        Pop-Location
    }
    exit 1
}

# Ensure we cleanup our location even if the script fails
trap {
    if ((Get-Location).Drive.Name -eq $SiteCode) {
        Pop-Location
    }
    throw $_
}

Write-Host "Starting Reboot - Toast deployment..." -ForegroundColor Green

$CIName = "Reboot - Toast"
$BaselineName = "Reboot - Toast"

# Cleanup existing objects
Write-Host "Cleaning up existing objects..." -ForegroundColor Yellow
try {
    # Remove existing baseline
    Write-Host "Removing existing baseline: $BaselineName" -ForegroundColor Yellow
    Get-CMBaseline -Name $BaselineName -Fast -ErrorAction SilentlyContinue | Remove-CMBaseline -Force
    Write-Host "Existing baseline removed" -ForegroundColor Green

    # Remove existing configuration item
    Write-Host "Removing existing configuration item: $CIName" -ForegroundColor Yellow
    Get-CMConfigurationItem -Name $CIName -Fast -ErrorAction SilentlyContinue | Remove-CMConfigurationItem -Force
    Write-Host "Existing configuration item removed" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Error during cleanup: $_" -ForegroundColor Yellow
    Write-Host "Continuing with script execution..." -ForegroundColor Yellow
}

# Reboot detection script
$RebootScript = @'
try {
    $RebootThreshold = 30
    $MinLogAge = 14        # Minimum days of log history required to trust no-reboot condition
    $Today = Get-Date
    $OverrideFile = "C:\reboottest.txt"

    # Determine OS architecture
    $Architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    $RebootKey = if ($Architecture -eq "32-bit") {
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reboot"
    } else {
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Reboot"
    }

    # Ensure registry key/value exists
    if (-not (Test-Path $RebootKey)) {
        New-Item -Path $RebootKey -Force | Out-Null
    }
    if (-not (Get-ItemProperty -Path $RebootKey -Name Rebooted -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $RebootKey -Name Rebooted -Value 0 -PropertyType DWORD -Force | Out-Null
    }
    $Rebooted = (Get-ItemProperty -Path $RebootKey -Name Rebooted).Rebooted

    # Get last reboot time using more reliable method
    $LastReboot = $null
    try {
        $LastReboot = Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = 1074} -MaxEvents 1 -ErrorAction Stop
    }
    catch {
        # Fallback to WMI if Get-WinEvent fails
        try {
            $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            if ($LastBootUpTime) {
                # Create a mock object similar to WinEvent for consistency
                $LastReboot = [PSCustomObject]@{
                    TimeCreated = $LastBootUpTime
                }
            }
        }
        catch {
            $LastReboot = $null
        }
    }

    # If override file exists, return high number to indicate non-compliance
    if (Test-Path $OverrideFile) {
        return 9999  # High number indicates forced non-compliance
    }

    # If no reboot event found, check system log age
    if (-not $LastReboot) {
        try {
            # Use a more conservative approach to get oldest log entry
            $OldestLogEntry = Get-WinEvent -LogName System -MaxEvents 1000 -ErrorAction Stop | 
                Sort-Object TimeCreated | Select-Object -First 1
            
            if ($OldestLogEntry) {
                $DaysSinceLogStart = [math]::Abs((New-TimeSpan -Start $OldestLogEntry.TimeCreated -End $Today).Days)
                
                # If logs are at least MinLogAge days old, return high number for non-compliance
                if ($DaysSinceLogStart -ge $MinLogAge) {
                    return 9998  # High number - no reboot found in sufficient log history
                }
                # If logs are too young, return low number for compliance
                else {
                    return 0     # Compliant - insufficient log history to determine
                }
            }
            else {
                # No logs found, assume recent reboot
                return 0
            }
        }
        catch {
            # Error accessing logs, assume recent reboot
            return 0
        }
    }

    # Calculate days since reboot
    $DaysSinceReboot = [math]::Round((New-TimeSpan -Start $LastReboot.TimeCreated -End $Today).TotalDays)
    
    # Return the actual number of days since reboot
    return [int]$DaysSinceReboot

}
catch {
    # If any unexpected error occurs, return 0 for safety
    return 0
}
'@

# Reboot remediation script (inline content)
$RemediationScript = @'
# Reboot Remediation Toast Notification
# This script shows a toast notification to remind users to reboot their system

try {
    # Check if we're running as logged in user (required for toast notifications)
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Running as user: $CurrentUser"

    # Check for override file to customize message
    $OverrideFile = "C:\reboottest.txt"
    $IsOverride = Test-Path $OverrideFile

    # Load required assemblies for toast notifications
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    # Customize toast message based on override file
    if ($IsOverride) {
        $ToastTitle = "🔧 System Reboot Required (Test Mode)"
        $ToastMessage1 = "IT has flagged this system for mandatory reboot testing."
        $ToastMessage2 = "Override file detected: $OverrideFile - Please restart to clear this flag."
        Write-Host "Override file detected - showing test mode notification"
    } else {
        $ToastTitle = "🔄 System Reboot Required"
        $ToastMessage1 = "Your computer needs to be restarted to maintain security and performance."
        $ToastMessage2 = "Last reboot was over 30 days ago. Please save your work and restart soon."
        Write-Host "Standard reboot notification"
    }

    # Toast notification XML template
    $ToastXml = @"
<toast scenario="reminder" activationType="protocol" launch="ms-settings:windowsupdate" duration="long">
    <visual>
        <binding template="ToastGeneric">
            <text>$ToastTitle</text>
            <text>$ToastMessage1</text>
            <text>$ToastMessage2</text>
            <image placement="appLogoOverride" hint-crop="circle" src="C:\Windows\System32\imageres.dll" />
        </binding>
    </visual>
    <actions>
        <action content="Restart Now" arguments="shutdown /r /t 300 /c 'System will restart in 5 minutes. Save your work.'" activationType="protocol" />
        <action content="Remind Me Later" arguments="dismiss" activationType="system" />
        <action content="Settings" arguments="ms-settings:windowsupdate" activationType="protocol" />
    </actions>
    <audio src="ms-winsoundevent:Notification.Reminder" loop="false" />
</toast>
"@

    # Create XML document
    $XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $XmlDoc.LoadXml($ToastXml)

    # Create toast notification
    $AppId = "Microsoft.SoftwareCenter.DesktopToasts"  # Use Software Center's app ID
    $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDoc)
    
    # Set expiration time (24 hours from now)
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddHours(24)
    
    # Show the toast
    $ToastNotifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
    $ToastNotifier.Show($Toast)

    Write-Host "Toast notification sent successfully"

    # Also create a registry entry to track that we've notified the user
    $NotificationKey = "HKCU:\SOFTWARE\IT\RebootNotifications"
    if (-not (Test-Path $NotificationKey)) {
        New-Item -Path $NotificationKey -Force | Out-Null
    }
    
    $LastNotification = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-ItemProperty -Path $NotificationKey -Name "LastRebootReminder" -Value $LastNotification
    Set-ItemProperty -Path $NotificationKey -Name "NotificationCount" -Value ((Get-ItemProperty -Path $NotificationKey -Name "NotificationCount" -ErrorAction SilentlyContinue).NotificationCount + 1)
    
    # Track override file usage
    if ($IsOverride) {
        Set-ItemProperty -Path $NotificationKey -Name "LastOverrideNotification" -Value $LastNotification
        Write-Host "Override notification tracking updated: $LastNotification"
    } else {
        Write-Host "Standard notification tracking updated: $LastNotification"
    }

    # Fallback notification using balloon tip if toast fails
}
catch {
    Write-Host "Toast notification failed, trying balloon tip fallback: $_"
    
    try {
        # Check for override file for fallback message too
        $OverrideFile = "C:\reboottest.txt"
        $IsOverride = Test-Path $OverrideFile
        
        # Fallback to balloon tip notification
        Add-Type -AssemblyName System.Windows.Forms
        $NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
        $NotifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        
        if ($IsOverride) {
            $NotifyIcon.BalloonTipTitle = "System Reboot Required (Test Mode)"
            $NotifyIcon.BalloonTipText = "IT has flagged this system for mandatory reboot testing. Override file detected: $OverrideFile - Please restart to clear this flag."
        } else {
            $NotifyIcon.BalloonTipTitle = "System Reboot Required"
            $NotifyIcon.BalloonTipText = "Your computer needs to be restarted. Last reboot was over 30 days ago. Please save your work and restart soon."
        }
        
        $NotifyIcon.Visible = $true
        $NotifyIcon.ShowBalloonTip(10000)  # Show for 10 seconds
        
        Start-Sleep -Seconds 11  # Wait for balloon to show
        $NotifyIcon.Dispose()
        
        Write-Host "Balloon tip notification sent successfully"
    }
    catch {
        Write-Host "All notification methods failed: $_"
        
        # Final fallback - create a desktop shortcut reminder
        try {
            $Desktop = [Environment]::GetFolderPath("Desktop")
            $OverrideFile = "C:\reboottest.txt"
            $IsOverride = Test-Path $OverrideFile
            
            if ($IsOverride) {
                $ShortcutPath = "$Desktop\⚠️ REBOOT REQUIRED (TEST MODE).url"
            } else {
                $ShortcutPath = "$Desktop\⚠️ REBOOT REQUIRED.url"
            }
            
            $ShortcutContent = @"
[InternetShortcut]
URL=ms-settings:windowsupdate
IconFile=C:\Windows\System32\imageres.dll
IconIndex=1
"@
            $ShortcutContent | Out-File -FilePath $ShortcutPath -Encoding ASCII
            Write-Host "Desktop reminder shortcut created: $ShortcutPath"
        }
        catch {
            Write-Host "Final fallback also failed: $_"
        }
    }
}

# Return success for SCCM remediation
return $true
'@

# Create the Configuration Item
Write-Host "Creating Configuration Item: $CIName" -ForegroundColor Yellow
try {
    # Create the CI
    $CI = New-CMConfigurationItem -Name $CIName -Description "Monitors days since last system reboot for compliance" -CreationType WindowsOS
    
    # Add script setting with compliance rule and remediation (run as logged-in user)
    $CI | Add-CMComplianceSettingScript -Name "Days Since Reboot" -DataType Integer -DiscoveryScriptLanguage PowerShell -DiscoveryScriptText $RebootScript -ValueRule -RuleName "Reboot within 30 days" -RuleDescription "System must be rebooted within 30 days" -ExpressionOperator "GreaterThan" -ExpectedValue 30 -ReportNoncompliance -NoncomplianceSeverity Warning -IsPerUser -Remediate -RemediationScriptLanguage PowerShell -RemediationScriptText $RemediationScript
    
    Write-Host "Configuration Item created successfully: $CIName" -ForegroundColor Green
}
catch {
    Write-Host "Error creating Configuration Item: $_" -ForegroundColor Red
    throw
}

# Create the Baseline
Write-Host "Creating Baseline: $BaselineName" -ForegroundColor Yellow
try {
    $Baseline = New-CMBaseline -Name $BaselineName -Description "Monitors system reboot compliance - systems must reboot within 30 days"
    Write-Host "Baseline created successfully: $BaselineName" -ForegroundColor Green
}
catch {
    Write-Host "Error creating Baseline: $_" -ForegroundColor Red
    throw
}

# Get the updated CI object
$UpdatedCI = Get-CMConfigurationItem -Name $CIName -Fast

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Open the SCCM console" -ForegroundColor Yellow
Write-Host "2. Navigate to Assets and Compliance > Compliance Settings > Configuration Baselines" -ForegroundColor Yellow
Write-Host "3. Right-click on '$BaselineName' and select 'Properties'" -ForegroundColor Yellow
Write-Host "4. Go to the 'Configuration Data' tab" -ForegroundColor Yellow
Write-Host "5. Click 'Add' > 'Configuration Items'" -ForegroundColor Yellow
Write-Host "6. Select the '$CIName' configuration item" -ForegroundColor Yellow
Write-Host "7. Click OK to save the baseline" -ForegroundColor Yellow
Write-Host "8. Deploy the baseline to your target collections" -ForegroundColor Yellow

Write-Host "`nCompliance Logic:" -ForegroundColor Cyan
Write-Host "- Compliant: 0-30 days since last reboot" -ForegroundColor Green
Write-Host "- Non-Compliant: More than 30 days since last reboot" -ForegroundColor Red
Write-Host "- Override: Place 'C:\reboottest.txt' file to force non-compliance" -ForegroundColor Yellow

# Make sure we return to the original location
if ((Get-Location).Drive.Name -eq $SiteCode) {
    Pop-Location
} 