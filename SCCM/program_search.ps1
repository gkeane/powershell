# Define the directories to search
$directories = @("C:\Program Files", "C:\Program Files (x86)")

# Function to get permissions for a file or folder
function GetPermissions {
    param (
        [string]$path
    )
    try {
        $acl = Get-Acl -Path $path -ErrorAction Stop
        return $acl.Access | Select-Object @{
            Name='Identity';Expression={$_.IdentityReference}
        }, @{
            Name='Permissions';Expression={$_.FileSystemRights}
        }, @{
            Name='AccessType';Expression={$_.AccessControlType}
        }
    }
    catch {
        Write-Warning "Unable to get ACL for path: $path"
        return $null
    }
}

# Function to check if "Everyone" has write access to a file or folder
function HasEveryoneWriteAccess {
    param (
        [string]$path
    )
    try {
        $acl = Get-Acl -Path $path -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to get ACL for path: $path"
        return $false
    }
    foreach ($access in $acl.Access) {
        if ($access.IdentityReference -eq "Everyone" -and $access.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write) {
            return $true
        }
    }
    return $false
}

# List to store results
$results = @()

# Search directories
foreach ($directory in $directories) {
    Get-ChildItem -Path $directory -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            if (HasEveryoneWriteAccess -path $_.FullName) {
                $permissions = GetPermissions -path $_.FullName
                $result = [PSCustomObject]@{
                    Path = $_.FullName
                    Permissions = $permissions
                }
                $results += $result
                
                # Print detailed output
                Write-Output "`nVulnerable Path: $($_.FullName)"
                Write-Output "Permissions:"
                $permissions | Format-Table -AutoSize
            }
        }
        catch {
            Write-Warning "Unable to process path: $($_.FullName)"
        }
    }
}

# Export results to CSV (optional)
$results | Export-Csv -Path "vulnerable_paths_with_permissions.csv" -NoTypeInformation