# Retrieve the current user's documents folder path
$documentsPath = [Environment]::GetFolderPath("MyDocuments")

# Set the output file path
$outputFile = "C:\profile_ps.txt"

# Write the documents path to the output file
$documentsPath | Out-File -FilePath $outputFile

# Output success message
Write-Host "Profile path has been written to: $outputFile"