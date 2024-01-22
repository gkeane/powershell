# Check if NuGet provider is installed
if (-not (Get-Module -Name PowerShellGet -ListAvailable)) {
    # NuGet provider is not installed, so install it
    Write-Host "PowerShellGet module is not installed. Installing..."

    try {
        # Install PowerShellGet module
        Install-Module -Name PowerShellGet -Force -Scope CurrentUser -AllowClobber

        Write-Host "PowerShellGet module has been installed successfully."
    } catch {
        Write-Error "Failed to install PowerShellGet module. Error: $_.Exception.Message"
    }
} else {
    Write-Host "PowerShellGet module is already installed."
}

# Install NuGet if not available
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "NuGet provider is not installed. Installing..."

    try {
        # Install NuGet provider
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser

        Write-Host "NuGet provider has been installed successfully."
    } catch {
        Write-Error "Failed to install NuGet provider. Error: $_.Exception.Message"
    }
} else {
    Write-Host "NuGet provider is already installed."
}

if(-not (Get-Module PSWindowsUpdate -ListAvailable)){
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

    try {
        # Install pswindowsupdate module
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser

        Write-Host "pswinupdate has been installed successfully."
    } catch {
        Write-Error "Failed to install pswindupdate. Error: $_.Exception.Message"
    }

}

Import-Module PSWindowsUpdate

$lastUpdate=Get-WUHistory -Last 50 | Where-Object { $_.Title -like '*Cumulative Update*' } | Sort-Object -Property Date -Descending | Select-Object -First 1

$lastUpdate.Title | Out-File -FilePath C:\ProgramData\Quest\KACE\user\winupd_name.txt