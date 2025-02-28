# Define the Java version display name
$javaDisplayName = "Java 8"

# Registry paths for 32-bit and 64-bit programs
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Loop through the registry paths
foreach ($path in $registryPaths) {
    # Get all installed programs in the registry path
    $installedPrograms = Get-ChildItem -Path $path -ErrorAction SilentlyContinue

    foreach ($program in $installedPrograms) {
        # Get program properties
        $programProperties = Get-ItemProperty -Path $program.PSPath -ErrorAction SilentlyContinue
        $displayName = $programProperties.DisplayName
        $uninstallString = $programProperties.UninstallString

        # Check if the display name matches Java 8
        if ($displayName -like "$javaDisplayName*") {
            Write-Host "Uninstalling $displayName from $path" -ForegroundColor Green
            
            if ($uninstallString) {
                # If the uninstall string is MSI-based, use msiexec
                if ($uninstallString -match "MsiExec.exe") {
                    # Replace /i with /x if present, otherwise just append /x
                    if ($uninstallString -match "/i") {
                        $uninstallCmd = $uninstallString -replace "/i", "/x" + " /quiet /norestart"
                    } else {
                        $uninstallCmd = $uninstallString + " /quiet /norestart"
                    }
                } else {
                    # Some Java versions may require double quotes
                    $uninstallCmd = "& '$uninstallString' /quiet /norestart"
                }

                # Execute the uninstall command
                Write-Host "Running: $uninstallCmd" -ForegroundColor Yellow
                Start-Process cmd.exe -ArgumentList "/c $uninstallCmd" -NoNewWindow -Wait
            } else {
                Write-Host "No uninstall string found for $displayName. Skipping..." -ForegroundColor Red
            }
        }
    }
}

Write-Host "Java 8 uninstallation process completed." -ForegroundColor Cyan
