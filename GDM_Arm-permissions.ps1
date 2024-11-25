# Define Builtin Users group
$builtinUsers = "BUILTIN\Users"

# Directories for permissions
$directories = @(
    "C:\ProgramData\ARMdef\ARM_Install",
    "C:\Program Files (x86)\ARM",  # or "C:\Program Files\ARM" for 32-bit
    "C:\ProgramData\ARMdef"
)

# Set file/folder permissions
foreach ($dir in $directories) {
    icacls $dir /grant "${builtinUsers}:(OI)(CI)F" /T
}

# Registry keys for permissions
$registryKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Gylling Data Management",
    "HKLM:\SOFTWARE\Gylling Data Management"
)

# Grant registry permissions
foreach ($key in $registryKeys) {
    $acl = Get-Acl $key
    $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule ("$builtinUsers", "FullControl", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $key -AclObject $acl
}

Write-Host "Permissions updated for Builtin Users group."
