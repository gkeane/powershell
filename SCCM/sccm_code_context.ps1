# Set the name of the module you want documentation from
$moduleName = "ConfigurationManager"

# Folder to store the documentation for Cursor's MCP context
$contextFolder = ".code-context"
if (-not (Test-Path $contextFolder)) {
    New-Item -Path $contextFolder -ItemType Directory | Out-Null
}

# Import the module (you might need to adjust for ConfigurationManager specifics)
Import-Module $moduleName -ErrorAction Stop

# Get all exported cmdlets from the module
$cmdlets = (Get-Command -Module $moduleName -CommandType Cmdlet).Name

foreach ($cmdlet in $cmdlets) {
    $outFile = Join-Path $contextFolder "$cmdlet.txt"
    try {
        Get-Help $cmdlet -Full | Out-File -FilePath $outFile -Encoding utf8
        Write-Host "Wrote help for $cmdlet"
    } catch {
        Write-Warning ("Failed to get help for {0}: {1}" -f $cmdlet, $_.Exception.Message)
    }
}
