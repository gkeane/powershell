# Accept input from the command line (path to the file)
param(
    [string]$filePath
)

# Check if the file exists
if (-not (Test-Path $filePath)) {
    Write-Host "File not found: $filePath"
    exit
}

# Read the file content in UTF16-LE encoding
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::Unicode)

# Convert the content to byte array
$bytes = [System.Text.Encoding]::Unicode.GetBytes($content)

# Base64 encode the byte array
$encoded = [System.Convert]::ToBase64String($bytes)

# Create the output file name by appending "_enc" before the file extension
$outputFilePath = [System.IO.Path]::GetFileNameWithoutExtension($filePath) + 
                  "_enc" + [System.IO.Path]::GetExtension($filePath)

# Write the encoded content to the output file
[System.IO.File]::WriteAllText($outputFilePath, $encoded)

# Optionally, display the output file path
Write-Host "Encoded file created at: $outputFilePath"
