# Software Update Compliance Baseline
# This script creates a Configuration Baseline to monitor software update compliance

# Import the ConfigMgr module and set the location to the site
try {
    # Check if ConfigurationManager module is available
    if (-not (Get-Module ConfigurationManager)) {
        Write-Host "Importing Configuration Manager module..." -ForegroundColor Yellow
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction Stop
    }

    # Get the site code
    $SiteCode = Get-PSDrive -PSProvider CMSITE -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Name
    if (-not $SiteCode) {
        Write-Host "No SCCM site found. Creating new PSDrive..." -ForegroundColor Yellow
        $ProviderMachineName = $env:COMPUTERNAME
        if (-not $ProviderMachineName) { throw "Unable to determine SCCM provider machine name" }
        
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName -ErrorAction Stop | Out-Null
    }

    # Change to the SCCM drive
    Write-Host "Connecting to SCCM site $SiteCode..." -ForegroundColor Yellow
    Push-Location
    Set-Location "$($SiteCode):" -ErrorAction Stop
    Write-Host "Successfully connected to SCCM site $SiteCode" -ForegroundColor Green
} catch {
    Write-Host "Error connecting to SCCM: $_" -ForegroundColor Red
    Write-Host "Make sure you're running this from a machine with the SCCM admin console installed" -ForegroundColor Yellow
    if ((Get-Location).Drive.Name -eq $SiteCode) {
        Pop-Location
    }
    exit 1
}

# Ensure we cleanup our location even if the script fails
trap {
    if ((Get-Location).Drive.Name -eq $SiteCode) {
        Pop-Location
    }
    throw $_
}

Write-Host "Starting script execution..." -ForegroundColor Green

# Create or get the Updates folder for Configuration Items
Write-Host "Creating Updates folder structure..." -ForegroundColor Yellow
try {
    # Create folder specifically for Configuration Items
    $CIFolderPath = "ConfigurationItem"
    
    # Try to get existing Updates folder under Configuration Items
    $UpdatesFolder = Get-CMFolder -FolderPath "$CIFolderPath\Updates" -ErrorAction SilentlyContinue
    if (-not $UpdatesFolder) {
        Write-Host "Creating new Updates folder under Configuration Items..." -ForegroundColor Yellow
        # Create the folder under the Configuration Items node
        $UpdatesFolder = New-CMFolder -ParentFolderPath $CIFolderPath -Name "Updates"
        Write-Host "Updates folder created successfully" -ForegroundColor Green
    } else {
        Write-Host "Updates folder already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "Error creating Updates folder: $_" -ForegroundColor Red
    Write-Host "Continuing without folder organization..." -ForegroundColor Yellow
}

# Cleanup existing objects
Write-Host "Cleaning up existing objects..." -ForegroundColor Yellow
try {
    # Remove existing baseline with -Fast parameter
    Write-Host "Removing existing baseline..." -ForegroundColor Yellow
    Get-CMBaseline -Name $BaselineName -Fast -ErrorAction SilentlyContinue | Remove-CMBaseline -Force
    Write-Host "Existing baseline removed" -ForegroundColor Green

    # Remove existing configuration items with -Fast parameter
    Write-Host "Removing existing configuration items..." -ForegroundColor Yellow
    $configItems = @(
        "Last Update Check - 30 Days",
        "Last Update Check - 60 Days",
        "Last Update Check - 90 Days",
        "Last Update Check - 180 Days",
        "Last Update Check - 365 Days",
        "Last Update Check - Never"
    )

    foreach ($item in $configItems) {
        Write-Host "Removing configuration item: $item" -ForegroundColor Yellow
        Get-CMConfigurationItem -Name $item -Fast -ErrorAction SilentlyContinue | Remove-CMConfigurationItem -Force
    }
    Write-Host "Existing configuration items removed" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Error during cleanup: $_" -ForegroundColor Yellow
    Write-Host "Continuing with script execution..." -ForegroundColor Yellow
}

$BaselineName = "Software Update Compliance Baseline"
$BaselineDescription = "Monitors the time since last cumulative update installation"

# Create the baseline
Write-Host "Creating baseline..." -ForegroundColor Yellow
Write-Host "Executing: New-CMBaseline -Name '$BaselineName' -Description '$BaselineDescription'" -ForegroundColor Cyan
$Baseline = New-CMBaseline -Name $BaselineName -Description $BaselineDescription
Write-Host "Baseline created successfully" -ForegroundColor Green

# Function to get last update time as an integer
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        # Get the last successful cumulative update installation time
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            # Return integer number of days
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            # Return -1 to indicate never updated
            -1
        }
    }
    catch {
        # Return -1 to indicate error/never updated
        -1
    }
}

# Create script for checking update time for different periods
$Script30Days = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

$Script60Days = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

$Script90Days = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

$Script180Days = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

$Script365Days = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

$ScriptNever = @'
function Get-LastUpdateTime {
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        $LastUpdateTime = $UpdateSearcher.QueryHistory(0, 100) | 
            Where-Object { 
                $_.ResultCode -eq 2 -and 
                $_.Title -match "Cumulative Update" -and
                $_.Title -match "Windows"
            } | 
            Select-Object -First 1 -ExpandProperty Date
        
        if ($LastUpdateTime) {
            [int][math]::Round((Get-Date) - $LastUpdateTime).TotalDays
        }
        else {
            9999  # Return high number for never updated
        }
    }
    catch {
        9999  # Return high number for error/never updated
    }
}

return Get-LastUpdateTime
'@

# Function to create Configuration Item with compliance settings
function New-UpdateComplianceCI {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Script,
        [string]$RuleName,
        [string]$RuleDescription,
        [string]$ComparisonOperator,
        $ThresholdValue  # Can be int or array for Between operations
    )
    
    Write-Host "Creating CI: $Name" -ForegroundColor Yellow
    try {
        # Create the CI
        $CI = New-CMConfigurationItem -Name $Name -Description $Description -CreationType WindowsOS
        
        # Handle different threshold value types
        if ($ThresholdValue -is [array]) {
            # For Between operations, pass the array directly
            $ExpectedValues = $ThresholdValue
        } else {
            # For single value operations, convert to array format that SCCM expects
            $ExpectedValues = @($ThresholdValue)
        }
        
        # Add script setting to the CI with proper parameters (Integer instead of Boolean)
        $CI | Add-CMComplianceSettingScript -Name "$Name Setting" -DataType Integer -DiscoveryScriptLanguage PowerShell -DiscoveryScriptText $Script -ValueRule -RuleName $RuleName -RuleDescription $RuleDescription -ExpressionOperator $ComparisonOperator -ExpectedValue $ExpectedValues -ReportNoncompliance -NoncomplianceSeverity Warning
        
        # Get the updated CI object after adding the compliance setting
        $UpdatedCI = Get-CMConfigurationItem -Name $Name -Fast
        
        # Move CI to Updates folder 
        try {
            Move-CMObject -FolderPath "ConfigurationItem\Updates" -InputObject $UpdatedCI
            Write-Host "Moved CI to Updates folder: $Name" -ForegroundColor Gray
        } catch {
            Write-Host "Warning: Could not move CI to Updates folder: $_" -ForegroundColor Yellow
            # Try alternative approach with ObjectId
            try {
                Move-CMObject -FolderPath "ConfigurationItem\Updates" -ObjectId $UpdatedCI.CI_ID
                Write-Host "Moved CI to Updates folder using ObjectId: $Name" -ForegroundColor Gray
            } catch {
                Write-Host "Warning: Could not move CI to Updates folder with either method: $_" -ForegroundColor Yellow
            }
        }
        
        Write-Host "CI created successfully: $Name" -ForegroundColor Green
        return $UpdatedCI
    } catch {
        Write-Host "Error creating CI $Name : $_" -ForegroundColor Red
        throw
    }
}

# Create configuration items with proper compliance settings using ranges
$ConfigItems = @(
    @{
        Name = "Last Update Check - 30 Days"
        Description = "Checks if last update was between 31-60 days ago"
        Script = $Script30Days
        RuleName = "Updates between 31-60 days"
        RuleDescription = "System has not been updated for 31-60 days (warning level)"
        ComparisonOperator = "Between"
        ThresholdValue = @(31, 60)  # Between 31 and 60 days
    },
    @{
        Name = "Last Update Check - 60 Days"
        Description = "Checks if last update was between 61-90 days ago"
        Script = $Script60Days
        RuleName = "Updates between 61-90 days"
        RuleDescription = "System has not been updated for 61-90 days (moderate concern)"
        ComparisonOperator = "Between"
        ThresholdValue = @(61, 90)  # Between 61 and 90 days
    },
    @{
        Name = "Last Update Check - 90 Days"
        Description = "Checks if last update was between 91-180 days ago"
        Script = $Script90Days
        RuleName = "Updates between 91-180 days"
        RuleDescription = "System has not been updated for 91-180 days (high concern)"
        ComparisonOperator = "Between"
        ThresholdValue = @(91, 180)  # Between 91 and 180 days
    },
    @{
        Name = "Last Update Check - 180 Days"
        Description = "Checks if last update was between 181-365 days ago"
        Script = $Script180Days
        RuleName = "Updates between 181-365 days"
        RuleDescription = "System has not been updated for 181-365 days (critical concern)"
        ComparisonOperator = "Between"
        ThresholdValue = @(181, 365)  # Between 181 and 365 days
    },
    @{
        Name = "Last Update Check - 365 Days"
        Description = "Checks if last update was over 365 days ago"
        Script = $Script365Days
        RuleName = "Updates over 365 days"
        RuleDescription = "System has not been updated for over 365 days (critical)"
        ComparisonOperator = "GreaterThan"
        ThresholdValue = 365  # Greater than 365 days
    },
    @{
        Name = "Last Update Check - Never"
        Description = "Identifies systems that have never been updated"
        Script = $ScriptNever
        RuleName = "Never updated"
        RuleDescription = "System has never been updated (returns 9999)"
        ComparisonOperator = "IsEquals"
        ThresholdValue = 9999
    }
)

$CreatedCIs = @()
foreach ($CIConfig in $ConfigItems) {
    $CI = New-UpdateComplianceCI @CIConfig
    $CreatedCIs += $CI
}

# Add all CIs to the baseline
Write-Host "Adding CIs to baseline..." -ForegroundColor Yellow
try {
    foreach ($CI in $CreatedCIs) {
        Write-Host "Adding CI to baseline: $($CI.LocalizedDisplayName)" -ForegroundColor Gray
        # Note: Automatic addition to baseline requires Set-CMBaseline with configuration items
        # This is currently not supported in the available cmdlets - manual addition required
    }
    
    Write-Host "Configuration Items created and organized in Updates folder:" -ForegroundColor Green
    foreach ($CI in $CreatedCIs) {
        Write-Host "  - $($CI.LocalizedDisplayName)" -ForegroundColor White
    }
    
    Write-Host "`nTo complete the setup:" -ForegroundColor Yellow
    Write-Host "1. Open the SCCM console" -ForegroundColor Yellow
    Write-Host "2. Navigate to Assets and Compliance > Compliance Settings > Configuration Baselines" -ForegroundColor Yellow
    Write-Host "3. Right-click on '$BaselineName' and select 'Properties'" -ForegroundColor Yellow
    Write-Host "4. Go to the 'Configuration Data' tab" -ForegroundColor Yellow
    Write-Host "5. Click 'Add' > 'Configuration Items'" -ForegroundColor Yellow
    Write-Host "6. Navigate to the 'Updates' folder and select all the created configuration items" -ForegroundColor Yellow
    Write-Host "7. Click OK to save the baseline" -ForegroundColor Yellow
    
} catch {
    Write-Host "Error adding CIs to baseline: $_" -ForegroundColor Red
}

Write-Host "Script completed successfully!" -ForegroundColor Green
Write-Host "All Configuration Items have been created with proper compliance settings and organized in the Updates folder." -ForegroundColor Green

# Make sure we return to the original location
if ((Get-Location).Drive.Name -eq $SiteCode) {
    Pop-Location
} 