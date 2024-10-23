param (
    [string]$filePath
)

# Check if the file exists in the current directory
$currentDirectory = Get-Location
$fullFilePath = Join-Path -Path $currentDirectory -ChildPath $filePath

if (-Not (Test-Path $fullFilePath)) {
    Write-Host "File not found: $fullFilePath"
    exit 1
}

# Read the content of the file
$fileContent = Get-Content -Path $fullFilePath -Raw -Encoding UTF8


# Convert the content to bytes
$bytes = [System.Text.Encoding]::Unicode.GetBytes($fileContent)

# Encode the bytes to a base64 string
$encodedContent = [Convert]::ToBase64String($bytes)

# Generate the new filename with _b64 before the extension
$filename = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
$extension = [System.IO.Path]::GetExtension($filePath)
$newFileName = "$filename`_b64$extension"
$newFilePath = Join-Path -Path $currentDirectory -ChildPath $newFileName

# Write the encoded content to the new file
Set-Content -Path $newFilePath -Value $encodedContent

Write-Host "Base64 encoded file created: $newFilePath"
