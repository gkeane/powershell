# Run as administrator
#Requires -RunAsAdministrator

# Enable necessary firewall rules
$firewallRules = @(
    "Windows Management Instrumentation (DCOM-In)",
    "Windows Management Instrumentation (WMI-In)",
    "Windows Management Instrumentation (ASync-In)",
    "Windows Remote Management (HTTP-In)"  # Changed from WSMAN-In
)

foreach ($rule in $firewallRules) {
    Write-Host "Enabling firewall rule: $rule"
    try {
        $fwRule = Get-NetFirewallRule -DisplayName $rule -ErrorAction Stop
        if ($fwRule) {
            $fwRule | Set-NetFirewallRule -Enabled True
            Write-Host "Enabled rule: $rule"
        }
    }
    catch {
        Write-Warning "Could not find firewall rule: $rule"
    }
}

# Enable WMI services
$services = @(
    @{Name="Winmgmt"; DisplayName="Windows Management Instrumentation"},
    @{Name="RpcSs"; DisplayName="Remote Procedure Call"},
    @{Name="RemoteRegistry"; DisplayName="Remote Registry"}
)

foreach ($service in $services) {
    Write-Host "Configuring service: $($service.DisplayName)"
    try {
        $svc = Get-Service -Name $service.Name -ErrorAction Stop
        if ($svc.StartType -ne 'Automatic') {
            Set-Service -Name $service.Name -StartupType Automatic
            Write-Host "Set $($service.DisplayName) to Automatic startup"
        }
        if ($svc.Status -ne 'Running') {
            Start-Service -Name $service.Name
            Write-Host "Started $($service.DisplayName) service"
        }
    }
    catch {
        Write-Warning "Error configuring $($service.DisplayName): $($_.Exception.Message)"
    }
}

# Configure DCOM settings
Write-Host "Configuring DCOM settings"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y"

# Configure WMI namespace security for all namespaces
Write-Host "Configuring WMI namespace security"
$namespaces = @(
    "ROOT",
    "ROOT\CIMV2",
    "ROOT\CANRspace",
    "ROOT\StandardCimv2",
    "ROOT\Subscription",
    "ROOT\DEFAULT"
)
$networkService = "NT AUTHORITY\NETWORK SERVICE"
$everyone = "Everyone"

foreach ($namespace in $namespaces) {
    foreach ($account in @($networkService, $everyone)) {
        $cmd = "wmimgmt.msc /norestore"
        Write-Host "`nPlease manually configure WMI permissions for $account in namespace: $namespace"
        Write-Host "1. Open $cmd"
        Write-Host "2. Right-click 'WMI Control' and select 'Properties'"
        Write-Host "3. Go to the 'Security' tab"
        Write-Host "4. Navigate to $namespace"
        Write-Host "5. Add $account with:"
        Write-Host "   - Enable Account"
        Write-Host "   - Remote Enable"
        Write-Host "   - Execute Methods"
        Write-Host "   - Provider Write"
        Write-Host "   - Enable Remote"
    }
}

Write-Host "`nConfiguration complete. Test remote access with:"
Write-Host "Get-WmiObject -Namespace ROOT\CIMV2 -Class Win32_ComputerSystem -ComputerName <thiscomputer>" 