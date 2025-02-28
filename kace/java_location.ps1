# Script to collect Java executable information for KACE
$ErrorActionPreference = "SilentlyContinue"

# Start timing the script
$startTime = Get-Date

# Initialize array to store results
$javaInstalls = @()

# Define paths to search
$searchPaths = @(
    "${env:ProgramFiles}",
    "${env:ProgramFiles(x86)}"
)

# Define system paths to check (no recursion needed)
$systemPaths = @(
    "${env:SystemRoot}\System32\java.exe",
    "${env:SystemRoot}\SysWOW64\java.exe"
)

# Define executables to look for
$javaExes = @("java.exe", "javaw.exe")

# Define output path
$outputPath = "C:\ProgramData\Quest\KACE\user\java_installations.log"
$progressPath = "C:\ProgramData\Quest\KACE\user\java_search_progress.log"

# Function to write progress
function Write-SearchProgress {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message - Found $($javaInstalls.Count) Java installations so far" | 
        Out-File -FilePath $progressPath -Append
}

Write-SearchProgress "Starting Java installation search"

# Check system paths first
Write-SearchProgress "Checking System directories"
foreach ($systemPath in $systemPaths) {
    if (Test-Path $systemPath) {
        $file = Get-Item $systemPath
        # Get file version info
        $fileInfo = Get-ItemProperty $file.FullName
        $versionInfo = $fileInfo.VersionInfo
        
        # Create formatted string with relevant information
        $javaEntry = "{0},{1},{2},{3},{4}" -f `
            $file.Name,
            $file.FullName,
            $versionInfo.FileVersion,
            $versionInfo.ProductVersion,
            $versionInfo.CompanyName

        # Add to results array
        $javaInstalls += $javaEntry
        Write-SearchProgress "Found Java in $($file.FullName)"
    }
}

# Then check Program Files directories
foreach ($basePath in $searchPaths) {
    Write-SearchProgress "Searching in $basePath"
    # Recursively search for java executables
    $files = Get-ChildItem -Path $basePath -Include $javaExes -Recurse

    foreach ($file in $files) {
        # Get file version info
        $fileInfo = Get-ItemProperty $file.FullName
        $versionInfo = $fileInfo.VersionInfo
        
        # Create formatted string with relevant information
        $javaEntry = "{0},{1},{2},{3},{4}" -f `
            $file.Name,
            $file.FullName,
            $versionInfo.FileVersion,
            $versionInfo.ProductVersion,
            $versionInfo.CompanyName

        # Add to results array
        $javaInstalls += $javaEntry
        Write-SearchProgress "Found Java in $($file.FullName)"
    }
}

# Join all entries with pipe separator and write to file
$javaInstalls -join "|" | Out-File -FilePath $outputPath -Force

# Calculate execution time in seconds
$executionTime = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

Write-SearchProgress "Search completed in $executionTime seconds"

# Return count and execution time
return "$($javaInstalls.Count),$executionTime"
