# Reboot Remediation Toast Notification
# This script shows a toast notification to remind users to reboot their system

try {
    # Check if we're running as logged in user (required for toast notifications)
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Running as user: $CurrentUser"

    # Load required assemblies for toast notifications
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    # Toast notification XML template
    $ToastXml = @"
<toast scenario="reminder" activationType="protocol" launch="ms-settings:windowsupdate" duration="long">
    <visual>
        <binding template="ToastGeneric">
            <text>🔄 System Reboot Required</text>
            <text>Your computer needs to be restarted to maintain security and performance.</text>
            <text>Last reboot was over 30 days ago. Please save your work and restart soon.</text>
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

    Write-Host "Notification tracking updated: $LastNotification"

    # Fallback notification using balloon tip if toast fails
}
catch {
    Write-Host "Toast notification failed, trying balloon tip fallback: $_"
    
    try {
        # Fallback to balloon tip notification
        Add-Type -AssemblyName System.Windows.Forms
        $NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
        $NotifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        $NotifyIcon.BalloonTipTitle = "System Reboot Required"
        $NotifyIcon.BalloonTipText = "Your computer needs to be restarted. Last reboot was over 30 days ago. Please save your work and restart soon."
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
            $ShortcutPath = "$Desktop\⚠️ REBOOT REQUIRED.url"
            
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
