# Function to check file permissions
function HasModifiablePermissions {
    param (
        [string]$path
    )
    try {
        $acl = Get-Acl -Path $path -ErrorAction Stop
        foreach ($access in $acl.Access) {
            if (($access.IdentityReference -eq "Everyone" -or 
                 $access.IdentityReference -eq "BUILTIN\Users") -and 
                ($access.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write)) {
                return $true
            }
        }
    }
    catch {
        Write-Warning "Unable to get ACL for path: $path"
    }
    return $false
}

# Function to check for unquoted service paths
function HasUnquotedSpaces {
    param (
        [string]$path
    )
    if ($path -like "* *" -and $path -notlike '"*"') {
        return $true
    }
    return $false
}

# Function to get service permissions
function GetServicePermissions {
    param (
        [string]$serviceName
    )
    try {
        $sd = New-Object System.Security.AccessControl.RawSecurityDescriptor(
            (sc.exe sdshow $serviceName) | Select-Object -Last 1
        )
        
        $dacl = $sd.DiscretionaryAcl | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.SecurityIdentifier.Translate([System.Security.Principal.NTAccount]).Value
                Rights = $_.AccessMask
                Type = $_.AceType
            }
        }
        return $dacl
    }
    catch {
        Write-Warning "Unable to get permissions for service: $serviceName"
        return $null
    }
}

# List to store vulnerable services
$vulnerableServices = @()

# Get all services
Get-WmiObject -Class Win32_Service | ForEach-Object {
    $service = $_
    $vulnerabilities = @()
    
    # Check for unquoted service paths
    if (HasUnquotedSpaces -path $service.PathName) {
        $vulnerabilities += "Unquoted Service Path"
    }
    
    # Check service binary permissions
    $binaryPath = $service.PathName.Split('"')[1]
    if (-not $binaryPath) {
        $binaryPath = $service.PathName.Split(' ')[0]
    }
    
    if (Test-Path $binaryPath) {
        if (HasModifiablePermissions -path $binaryPath) {
            $vulnerabilities += "Modifiable Binary"
        }
    }
    
    # Get service permissions
    $servicePermissions = GetServicePermissions -serviceName $service.Name
    $hasVulnerableServicePerms = $servicePermissions | Where-Object {
        ($_.Identity -in @("Everyone", "BUILTIN\Users")) -and 
        (
            ($_.Rights -band 0x20000) -or  # SERVICE_START
            ($_.Rights -band 0x40000) -or  # SERVICE_STOP
            ($_.Rights -band 0x10000) -or  # SERVICE_PAUSE_CONTINUE
            ($_.Rights -band 0xF01FF)      # SERVICE_ALL_ACCESS
        )
    }
    
    if ($hasVulnerableServicePerms) {
        $vulnerabilities += "Vulnerable Service Permissions"
    }
    
    # If any vulnerabilities found, add to results
    if ($vulnerabilities.Count -gt 0) {
        $vulnerableServices += [PSCustomObject]@{
            ServiceName = $service.Name
            DisplayName = $service.DisplayName
            PathName = $service.PathName
            StartMode = $service.StartMode
            State = $service.State
            Vulnerabilities = $vulnerabilities -join ", "
            ServicePermissions = $servicePermissions
        }
    }
}

# Output results
Write-Output "`nVulnerable Services Found:`n"
$vulnerableServices | ForEach-Object {
    Write-Output "Service Name: $($_.ServiceName)"
    Write-Output "Display Name: $($_.DisplayName)"
    Write-Output "Path: $($_.PathName)"
    Write-Output "Start Mode: $($_.StartMode)"
    Write-Output "State: $($_.State)"
    Write-Output "Vulnerabilities: $($_.Vulnerabilities)"
    Write-Output "Service Permissions:"
    $_.ServicePermissions | Format-Table -AutoSize
    Write-Output ("-" * 80)
}

# Export results to CSV
$vulnerableServices | Export-Csv -Path "vulnerable_services.csv" -NoTypeInformation 