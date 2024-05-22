<#
.SYNOPSIS
    Displays a reboot prompt every hour if the system hasn't rebooted in a specified number of days.

.DESCRIPTION
    This script checks the last reboot time of the system and, if it hasn't rebooted in a specified
    number of days, it displays a dialog box every hour asking the user if they want to reboot the system.

.PARAMETER daysWithoutReboot
    The number of days without a reboot required to trigger the prompt.

.EXAMPLE
    .\reboot_prompt.ps1 -daysWithoutReboot 7
    Runs the script and displays a reboot prompt every hour if the system hasn't rebooted in the last 7 days.

.NOTES
    This script should be run with administrative privileges.
#>

# Example of how to call this script:
# .\reboot_prompt.ps1 -daysWithoutReboot 7

Add-Type -AssemblyName PresentationFramework

param (
    [int]$daysWithoutReboot = 7
)

# Function to get the last reboot time using WMI
function Get-LastRebootTime {
    # Query the Win32_OperatingSystem class to get the last boot up time
    $os = Get-WmiObject -Class Win32_OperatingSystem
    return $os.ConvertToDateTime($os.LastBootUpTime)
}

# Function to show the reboot prompt dialog box
function Show-RebootPrompt {
    # Load necessary assemblies for creating the dialog box
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')

    # Create the form
    $form = New-Object Windows.Forms.Form
    $form.Text = 'System Reboot'
    $form.Size = New-Object Drawing.Size(300,150)
    $form.StartPosition = 'CenterScreen'

    # Create and add a label to the form
    $label = New-Object Windows.Forms.Label
    $label.Text = "Would you like to reboot now?"
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(75,20)
    $form.Controls.Add($label)

    # Create and add the Yes button to the form
    $yesButton = New-Object Windows.Forms.Button
    $yesButton.Text = 'Yes'
    $yesButton.Location = New-Object Drawing.Point(50,60)
    $yesButton.Add_Click({
        Restart-Computer -Force # Reboot the system if Yes is clicked
    })
    $form.Controls.Add($yesButton)

    # Create and add the No button to the form
    $noButton = New-Object Windows.Forms.Button
    $noButton.Text = 'No'
    $noButton.Location = New-Object Drawing.Point(150,60)
    $noButton.Add_Click({
        $form.Close() # Close the form if No is clicked
    })
    $form.Controls.Add($noButton)

    # Set the form to always be on top
    $form.Topmost = $true
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog()
}

# Calculate the number of days since the last reboot
$lastReboot = Get-LastRebootTime
$daysSinceLastReboot = (Get-Date) - $lastReboot

# Check if the machine has not rebooted in the specified number of days
if ($daysSinceLastReboot.Days -ge $daysWithoutReboot) {
    # Loop to show the reboot prompt every hour if the condition is met
    while ($true) {
        Show-RebootPrompt
        Start-Sleep -Seconds 3600 # Wait for one hour before showing the prompt again
    }
} else {
    Write-Host "The system has rebooted within the last $daysWithoutReboot days."
}
