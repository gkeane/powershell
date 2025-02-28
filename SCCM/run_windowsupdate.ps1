# Set script requirements
#Requires -Version 3.0
#Requires -RunAsAdministrator

try {
    # Initialize
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WindowsUpdate.log"

    # Function to write logs in CMTrace format
    function Write-CMLog {
        param($Message)
        $Time = Get-Date -Format "HH:mm:ss.ffffff"
        $Date = Get-Date -Format "MM-dd-yyyy"
        $LogMessage = "<![LOG[$Message]LOG]!><time=`"$Time`" date=`"$Date`" component=`"WindowsUpdate`" context=`"`" type=`"1`" thread=`"`" file=`"`">"
        Add-Content -Path $LogPath -Value $LogMessage
        Write-Host $Message
    }

    Write-CMLog "Starting Windows Update process..."

    # Check for admin rights
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        throw "Script requires administrative privileges"
    }

    # Check if PSWindowsUpdate module is installed
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-CMLog "Installing PSWindowsUpdate module..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module PSWindowsUpdate -Force -Confirm:$false
    }

    # Import the module
    Import-Module PSWindowsUpdate -Force

    # Check for updates
    Write-CMLog "Checking for Windows Updates..."
    $updates = Get-WindowsUpdate

    if ($updates.Count -eq 0) {
        Write-CMLog "No updates available."
        exit 0
    }

    Write-CMLog "Found $($updates.Count) update(s)"
    foreach ($update in $updates) {
        Write-CMLog "Update found: $($update.Title)"
    }

    # Install updates
    Write-CMLog "Installing updates..."
    $installResult = Install-WindowsUpdate -AcceptAll -AutoReboot:$false -Verbose *>&1
    $installResult | ForEach-Object { Write-CMLog $_.ToString() }

    Write-CMLog "Windows Update process completed successfully."
    exit 0
}
catch {
    $errorMessage = $_.Exception.Message
    Write-CMLog "Error occurred: $errorMessage"
    Write-CMLog "Script failed with error details: $($_ | Format-List -Force | Out-String)"
    exit 1
} 