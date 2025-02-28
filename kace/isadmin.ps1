# Define the output file path
$outputFile = "C:\ProgramData\Quest\KACE\user\admin_check.txt"

# Get the current user's security principal
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)

# Check if the current user is an Administrator
$IsAdmin = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

# Write the result to the file
if ($IsAdmin) {
    "Yes" | Out-File -FilePath $outputFile -Encoding UTF8
} else {
    "No" | Out-File -FilePath $outputFile -Encoding UTF8
}
