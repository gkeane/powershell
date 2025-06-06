<#
.SYNOPSIS
    Monitors folders for executable files and creates AppLocker rules in a specified Group Policy Object.

.DESCRIPTION
    This script watches specified folders for .exe files and automatically creates AppLocker rules in a GPO.
    It supports both publisher-based and file-specific rules, handles log rotation, and includes debug logging capabilities.

.PARAMETER Debug
    When specified, enables detailed debug logging for troubleshooting.

.PARAMETER TestEmail
    If specified, sends a test email and exits.

.NOTES
    File Name      : monitor-and-process-exe.ps1
    Prerequisite   : PowerShell 5.1 or later
    Requirements   : - Domain Admin or delegated GPO permissions
                    - AppLocker service running
                    - Access to create/modify GPOs
#>

# Script parameters
param(
    [switch]$Debug,         # Enable/disable debug logging
    [switch]$TestEmail      # Send a test email and exit
)

#Region Configuration
# Base paths for file processing
$watchFolderPublisher = "C:\applocker\Watch\Publisher"  # Folder for publisher-based rules
$watchFolderFile = "C:\applocker\Watch\File"           # Folder for file-specific rules
$watchFolderHash = "C:\applocker\Watch\Hash"           # Folder for hash-based rules
$finishedFolder = "C:\applocker\Finished\Folder"       # Where files are moved after processing
$errorFolder = "C:\applocker\Error\Folder"             # Where files are moved if processing fails
$logFile = "C:\applocker\Logs\exe_processing.log"      # Current log file path
$logArchiveFolder = "C:\applocker\Logs\Archive"        # Where old logs are stored
$gpoName = "AppLocker2"                                # Name of the GPO to manage

# Email Configuration
$emailConfig = @{
    SmtpServer = "mail.udel.edu"      # SMTP server address
    From = "noreply@udel.edu"         # From address
    To = "gkeane@udel.edu"            # To address
    Subject = "AppLocker Rule Processing Report"  # Default subject
}

# Add new hash policy folder
$hashPolicyFile = "C:\applocker\Config\hash_rules.xml" # File to store hash rules
$hashConfigFolder = "C:\applocker\Config"              # Configuration folder
#EndRegion Configuration

#Region Log Management
<#
.SYNOPSIS
    Manages log rotation, compression, and cleanup.

.DESCRIPTION
    - Moves current log to archive with timestamp
    - Compresses logs older than 30 days
    - Deletes logs older than 1 year
#>
function Rotate-Logs {
    # Create archive folder if it doesn't exist
    if (!(Test-Path $logArchiveFolder)) {
        New-Item -ItemType Directory -Path $logArchiveFolder -Force
    }
    
    # Move current log to archive with timestamp if it exists
    if (Test-Path $logFile) {
        $timestamp = Get-Date -Format "yyyyMMdd"
        $archiveFile = Join-Path $logArchiveFolder "exe_processing_$timestamp.log"
        
        # If log from today already exists, append to it
        if (Test-Path $archiveFile) {
            Get-Content $logFile | Add-Content $archiveFile
        } else {
            Move-Item $logFile $archiveFile -Force
        }
    }
    
    # Get all log files in archive
    $allLogs = Get-ChildItem $logArchiveFolder -Filter "exe_processing_*.log"
    
    # Compress files older than 30 days
    $thirtyDaysAgo = (Get-Date).AddDays(-30)
    $allLogs | Where-Object {
        $_.LastWriteTime -lt $thirtyDaysAgo -and 
        $_.Extension -eq ".log"
    } | ForEach-Object {
        $zipFile = "$($_.FullName).zip"
        if (!(Test-Path $zipFile)) {
            Compress-Archive -Path $_.FullName -DestinationPath $zipFile
            Remove-Item $_.FullName
            Write-Log "Compressed log file: $($_.Name)"
        }
    }
    
    # Delete files older than 1 year
    $oneYearAgo = (Get-Date).AddDays(-365)
    $allLogs = Get-ChildItem $logArchiveFolder -Filter "exe_processing_*.log*"
    $allLogs | Where-Object {
        $_.LastWriteTime -lt $oneYearAgo
    } | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Log "Deleted old log file: $($_.Name)"
    }
}

<#
.SYNOPSIS
    Writes a message to the log file and console.

.PARAMETER Message
    The message to log.

.PARAMETER Debug
    If specified, message is only written when script is running in debug mode.
#>
function Write-Log {
    param(
        [string]$Message,
        [switch]$Debug
    )
    
    # Only write debug messages if debug mode is enabled
    if ($Debug -and -not $script:Debug) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Add-Content -Path $logFile
    Write-Host "$timestamp - $Message"
}
#EndRegion Log Management

#Region Email Functions
<#
.SYNOPSIS
    Sends an email notification using the configured SMTP server.

.PARAMETER Body
    The body of the email message.

.PARAMETER Subject
    Optional: Override the default subject line.

.PARAMETER IsError
    If true, marks the email as high importance and modifies the subject line.
#>
function Send-NotificationEmail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Body,
        [string]$Subject = $emailConfig.Subject,
        [switch]$IsError
    )
    
    try {
        $emailParams = @{
            SmtpServer = $emailConfig.SmtpServer
            From = $emailConfig.From
            To = $emailConfig.To
            Subject = $Subject
            Body = $Body
        }
        
        if ($IsError) {
            $emailParams.Priority = "High"
            $emailParams.Subject = "ERROR: $Subject"
        }
        
        Send-MailMessage @emailParams
        Write-Log "Email notification sent successfully" -Debug
    }
    catch {
        Write-Log "Failed to send email notification: $($_.Exception.Message)" -Debug
        # Don't throw here - we don't want email failures to stop processing
    }
}
#EndRegion Email Functions

# Move this section after the function definition
if ($TestEmail) {
    Write-Host "Sending test email..."
    Send-NotificationEmail -Body "This is a test email from the AppLocker Rule Processing script."
    Write-Host "Test email sent. Please check your inbox."
    exit
}

function Initialize-Environment {
    # Create base folder if it doesn't exist
    $baseFolder = "C:\applocker"
    if (!(Test-Path $baseFolder)) {
        New-Item -ItemType Directory -Path $baseFolder -Force
    }

    # Add Hash folder to the folders array
    $folders = @(
        "$baseFolder\Watch\Publisher",
        "$baseFolder\Watch\File",
        "$baseFolder\Watch\Hash",      # New Hash folder
        "$baseFolder\Config",          # New Config folder
        "$baseFolder\Finished\Folder",
        "$baseFolder\Error\Folder",
        "$baseFolder\Logs",
        "$baseFolder\Logs\Archive"
    )
    
    foreach ($folder in $folders) {
        if (!(Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force
            Write-Log "Created folder: $folder"
        }
    }
    
    # Rotate logs at startup
    Rotate-Logs
    
    # Check if GPO exists, create if it doesn't
    try {
        $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
        Write-Log "Found existing $gpoName GPO"
    } catch [System.ArgumentException] {
        # Only create new GPO if the error was that it doesn't exist
        $gpo = New-GPO -Name $gpoName
        Write-Log "Created new $gpoName GPO"
        
        # Get domain controller name
        $domainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
        Write-Log "DEBUG: Domain Controller: $domainController"
        
        # Format the LDAP path properly
        $ldapPath = "LDAP://$domainController/$($gpo.Path)"
        Write-Log "DEBUG: Using LDAP path: $ldapPath"
        
        # Initialize empty AppLocker policy with proper structure
        $basePolicy = @"
<?xml version="1.0"?>
<AppLockerPolicy Version="1">
    <RuleCollection Type="Exe" EnforcementMode="AuditOnly">
        <FilePublisherRule Id="$(New-Guid)" Name="(Default Rule) All signed packaged apps" Description="Allows members of the Everyone group to run packaged apps that are signed." UserOrGroupSid="S-1-1-0" Action="Allow">
            <Conditions>
                <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
                    <BinaryVersionRange LowSection="0.0.0.0" HighSection="*"/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
    </RuleCollection>
</AppLockerPolicy>
"@
        Set-AppLockerPolicy -XmlPolicy $basePolicy -Ldap $ldapPath -Domain
        Write-Log "Initialized AppLocker policy"
    }
}

# Initialize environment before doing anything else
Initialize-Environment

function Get-ExistingAppLockerPolicy {
    param(
        [string]$LdapPath
    )
    try {
        return Get-AppLockerPolicy -Domain -Ldap $LdapPath -Xml
    } catch {
        Write-Log "Error getting existing AppLocker policy: $($_.Exception.Message)" -Debug
        throw
    }
}

function Test-RuleExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$RuleType,
        [string]$LdapPath
    )
    try {
        $currentPolicy = Get-ExistingAppLockerPolicy -LdapPath $LdapPath
        $policyXml = [xml]$currentPolicy
        $fileInfo = Get-AppLockerFileInformation -Path $FilePath
        
        switch ($RuleType) {
            "Hash" {
                $fileHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
                $existingRule = $policyXml.SelectNodes("//FileHashRule") | 
                    Where-Object { $_.Conditions.FileHashCondition.FileHash.Hash -eq $fileHash }
            }
            "Publisher" {
                if ($fileInfo.Publisher) {
                    $publisher = $fileInfo.Publisher.PublisherName
                    $productName = $fileInfo.Publisher.ProductName
                    $fileName = $fileInfo.Publisher.BinaryName
                    
                    $existingRule = $policyXml.SelectNodes("//FilePublisherRule") | 
                        Where-Object { 
                            $_.Conditions.FilePublisherCondition.PublisherName -eq $publisher -and
                            $_.Conditions.FilePublisherCondition.ProductName -eq $productName -and
                            $_.Conditions.FilePublisherCondition.BinaryName -eq $fileName
                        }
                } else {
                    Write-Log "No publisher information found for $FilePath" -Debug
                    return $false
                }
            }
            "File" {
                $path = (Get-Item $FilePath).FullName
                $existingRule = $policyXml.SelectNodes("//FilePathRule") | 
                    Where-Object { $_.Conditions.FilePathCondition.Path -eq $path }
            }
        }
        
        if ($existingRule) {
            Write-Log "Found existing $RuleType rule for: $FilePath" -Debug
            return $true
        }
        
        Write-Log "No existing $RuleType rule found for: $FilePath" -Debug
        return $false
        
    } catch {
        Write-Log "Error checking for existing $RuleType rule: $($_.Exception.Message)" -Debug
        throw
    }
}

# Modify Add-AppLockerRule to use the new check
function Add-AppLockerRule {
    param(
        [string]$FilePath,
        [string]$RuleType
    )
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        Write-Log "Starting Add-AppLockerRule for $fileName" -Debug
        
        # Get existing GPO and its AppLocker policy
        Write-Log "Attempting to get GPO $gpoName" -Debug
        $gpo = Get-GPO -Name $gpoName
        Write-Log "Got GPO. Attempting to get AppLocker policy" -Debug
        
        try {
            # Get the domain controller name
            $domainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
            Write-Log "Domain Controller: $domainController" -Debug
            
            # Format the LDAP path properly
            $ldapPath = "LDAP://$domainController/$($gpo.Path)"
            Write-Log "Using LDAP path: $ldapPath" -Debug
            
            # Check if rule already exists
            if (Test-RuleExists -FilePath $FilePath -RuleType $RuleType -LdapPath $ldapPath) {
                Write-Log "Rule already exists for $fileName" -Debug
                Send-NotificationEmail -Body "Skipped creating $RuleType rule for $fileName - rule already exists"
                return $true
            }
            
            Write-Log "Creating new AppLocker rule from file information" -Debug
            
            # Get file information and create policy
            Write-Log "Getting file information..." -Debug
            $fileInfo = Get-AppLockerFileInformation -Path $FilePath
            Write-Log "File information retrieved:" -Debug
            Write-Log ($fileInfo | Format-List | Out-String) -Debug
            
            Write-Log "Creating new policy..." -Debug
            $newPolicy = New-AppLockerPolicy -FileInformation $fileInfo `
                                           -RuleType $RuleType `
                                           -User "Everyone" `
                                           -RuleNamePrefix "AUTO-"
            Write-Log "New policy created:" -Debug
            Write-Log ($newPolicy | Format-List | Out-String) -Debug
            
            Write-Log "Setting policy with merge..." -Debug
            Write-Log "LDAP path: $ldapPath" -Debug
            Write-Log "Policy object type: $($newPolicy.GetType().FullName)" -Debug
            
            # Set the policy with merge
            Set-AppLockerPolicy -PolicyObject $newPolicy -Ldap $ldapPath -Merge
            
            Write-Log "Successfully added and merged AppLocker rules for $fileName"
            
        } catch {
            Write-Log "Error manipulating AppLocker policy: $($_.Exception.Message)" -Debug
            Write-Log "Full Error: $_" -Debug
            throw
        }
        
    } catch {
        Write-Log "Error in Add-AppLockerRule: $($_.Exception.Message)" -Debug
        Write-Log "Error type: $($_.Exception.GetType().FullName)" -Debug
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Debug
        throw
    }
}

function Get-ExistingAppLockerPolicy {
    param(
        [string]$LdapPath
    )
    try {
        return Get-AppLockerPolicy -Domain -Ldap $LdapPath -Xml
    } catch {
        Write-Log "Error getting existing AppLocker policy: $($_.Exception.Message)" -Debug
        throw
    }
}

# Add function to check for existing hash rules
function Test-HashExists {
    param(
        [string]$Hash,
        [string]$LdapPath
    )
    try {
        $currentPolicy = Get-AppLockerPolicy -Domain -Ldap $LdapPath -Xml
        
        # Convert XML policy to object
        $policyXml = [xml]$currentPolicy
        
        # Check for hash in FileHashRule nodes
        $existingHash = $policyXml.SelectNodes("//FileHashRule") | 
            Where-Object { $_.Conditions.FileHashCondition.FileHash.Hash -eq $Hash }
        
        if ($existingHash) {
            Write-Log "Found existing hash rule for: $Hash" -Debug
            return $true
        }
        
        Write-Log "No existing hash rule found for: $Hash" -Debug
        return $false
        
    } catch {
        Write-Log "Error checking for existing hash: $($_.Exception.Message)" -Debug
        throw
    }
}

# Modify Add-AppLockerHashRule to check for existing rules
function Add-AppLockerHashRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [string]$RuleName = ""
    )
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        Write-Log "Creating hash-based rule for $fileName" -Debug
        
        # Calculate file hash
        $fileHash = Get-FileHash -Path $FilePath -Algorithm SHA256
        
        # Get domain controller and LDAP path
        $domainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
        $gpo = Get-GPO -Name $gpoName
        $ldapPath = "LDAP://$domainController/$($gpo.Path)"
        
        # Check if hash rule already exists
        if (Test-HashExists -Hash $fileHash.Hash -LdapPath $ldapPath) {
            Write-Log "Hash rule already exists for $fileName" -Debug
            Send-NotificationEmail -Body "Skipped creating hash rule for $fileName - rule already exists" 
            return $true
        }
        
        # Continue with existing rule creation code
        if ([string]::IsNullOrEmpty($RuleName)) {
            $RuleName = "HASH-$fileName"
        }
        
        # Get file information and create rule
        $fileInfo = Get-AppLockerFileInformation -Path $FilePath
        
        $hashRule = New-AppLockerPolicy -FileInformation $fileInfo `
            -RuleType Hash `
            -RuleName $RuleName `
            -User Everyone `
            -Action Allow
            
        # Merge with existing policy
        Set-AppLockerPolicy -PolicyObject $hashRule -Ldap $ldapPath -Merge
        
        # Log success
        Write-Log "Successfully created hash-based rule for $fileName (Hash: $($fileHash.Hash))"
        
        # Save hash information to config file
        $hashInfo = @{
            FileName = $fileName
            Hash = $fileHash.Hash
            RuleName = $RuleName
            DateAdded = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        if (!(Test-Path $hashConfigFolder)) {
            New-Item -ItemType Directory -Path $hashConfigFolder -Force
        }
        
        if (Test-Path $hashPolicyFile) {
            $existingRules = Import-Clixml $hashPolicyFile
            $existingRules += $hashInfo
        } else {
            $existingRules = @($hashInfo)
        }
        
        $existingRules | Export-Clixml $hashPolicyFile
        
        $emailBody = @"
Successfully created hash-based AppLocker rule:
File: $fileName
Hash: $($fileHash.Hash)
Rule Name: $RuleName
Date Added: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
"@
        Send-NotificationEmail -Body $emailBody
        
        return $true
    }
    catch {
        Write-Log "Error creating hash-based rule: $($_.Exception.Message)" -Debug
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Debug
        
        $errorMessage = $_.Exception.Message
        Send-NotificationEmail -Body "Error creating hash-based rule for $fileName : $errorMessage" -IsError
        return $false
    }
}

# Modify Process-File to handle hash rules
function Process-File {
    param(
        [string]$FilePath,
        [string]$RuleType
    )
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        $fileHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
        Write-Log "Processing $RuleType rule for: $fileName (Hash: $fileHash)"
        
        # Enhanced publisher information check
        $fileInfo = Get-AppLockerFileInformation -Path $FilePath -ErrorAction Stop
        
        if ($RuleType -eq "Publisher") {
            Write-Log "Checking publisher information for $fileName" -Debug
            
            # Detailed publisher check
            if (-not $fileInfo.Publisher) {
                $errorMsg = "Cannot create publisher rule - File is not signed"
                Write-Log $errorMsg
                
                # Get more details about the file
                $fileCertificate = (Get-AuthenticodeSignature -FilePath $FilePath).SignerCertificate
                $certStatus = (Get-AuthenticodeSignature -FilePath $FilePath).Status
                
                $emailBody = @"
Failed to create Publisher-based AppLocker rule:
File: $fileName
Location: $FilePath
Hash: $fileHash
Certificate Status: $certStatus

File Details:
$(if ($fileCertificate) {
    "Certificate Found: Yes
    Subject: $($fileCertificate.Subject)
    Issuer: $($fileCertificate.Issuer)
    Valid From: $($fileCertificate.NotBefore)
    Valid To: $($fileCertificate.NotAfter)"
} else {
    "Certificate Found: No"
})

Error: $errorMsg

Recommended Actions:
1. Verify the file is properly signed
2. Check if the certificate is valid and trusted
3. Consider using a Hash-based rule instead
4. Contact the software vendor if signature is missing
"@
                Send-NotificationEmail -Body $emailBody -Subject "AppLocker Publisher Rule Creation Failed" -IsError
                
                # Move to error folder
                $errorPath = Join-Path $errorFolder $fileName
                Move-Item -Path $FilePath -Destination $errorPath -Force
                Write-Log "Moved $fileName to error folder"
                return
            }
            
            # Log publisher details if found
            Write-Log "Publisher found: $($fileInfo.Publisher.PublisherName)" -Debug
            Write-Log "Product name: $($fileInfo.Publisher.ProductName)" -Debug
            Write-Log "Binary name: $($fileInfo.Publisher.BinaryName)" -Debug
        }
        
        # Continue with rule creation based on type
        switch ($RuleType) {
            "Hash" {
                Add-AppLockerHashRule -FilePath $FilePath
            }
            "Publisher" {
                Add-AppLockerRule -FilePath $FilePath -RuleType "Publisher"
            }
            "File" {
                Add-AppLockerRule -FilePath $FilePath -RuleType "File"
            }
        }
        
        # Move to finished folder only on success
        $destinationPath = Join-Path $finishedFolder $fileName
        Move-Item -Path $FilePath -Destination $destinationPath -Force
        Write-Log "Moved $fileName to finished folder"
        
    } catch {
        Write-Log "Error processing $fileName : $($_.Exception.Message)"
        
        # Send detailed error notification
        $emailBody = @"
Error processing AppLocker rule:
File: $fileName
Type: $RuleType
Location: $FilePath
Hash: $fileHash
Error: $($_.Exception.Message)

Stack Trace:
$($_.ScriptStackTrace)

Action Required: Please review the error and take appropriate action.
"@
        Send-NotificationEmail -Body $emailBody -Subject "AppLocker Rule Creation Error" -IsError
        
        # Move file to error folder
        $errorPath = Join-Path $errorFolder $fileName
        Move-Item -Path $FilePath -Destination $errorPath -Force
        Write-Log "Moved $fileName to error folder"
    }
}

Write-Log "Starting folder scan..."

# Process Publisher folder
Get-ChildItem -Path $watchFolderPublisher -Filter "*.exe" | ForEach-Object {
    Process-File -FilePath $_.FullName -RuleType "Publisher"
}

# Process File folder
Get-ChildItem -Path $watchFolderFile -Filter "*.exe" | ForEach-Object {
    Process-File -FilePath $_.FullName -RuleType "File"
}

# Process Hash folder
Get-ChildItem -Path $watchFolderHash -Filter "*.exe" | ForEach-Object {
    Process-File -FilePath $_.FullName -RuleType "Hash"
}

Write-Log "Folder scan completed." 