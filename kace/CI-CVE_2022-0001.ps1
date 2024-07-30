# Function to check registry values for mitigation
function Check-Mitigation {
    param (
        [int]$FeatureSettingsOverrideExpected,
        [int]$FeatureSettingsOverrideMaskExpected,
        [string]$MinVmVersionForCpuBasedMitigationsExpected = "1.0"
    )

    $featureSettingsOverride = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    $featureSettingsOverrideMask = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue
    $minVmVersionForCpuBasedMitigations = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" -Name "MinVmVersionForCpuBasedMitigations" -ErrorAction SilentlyContinue

    if ($featureSettingsOverride.FeatureSettingsOverride -eq $FeatureSettingsOverrideExpected -and `
        $featureSettingsOverrideMask.FeatureSettingsOverrideMask -eq $FeatureSettingsOverrideMaskExpected) {
        
        if ($minVmVersionForCpuBasedMitigations.MinVmVersionForCpuBasedMitigations -eq $MinVmVersionForCpuBasedMitigationsExpected -or $null -eq $minVmVersionForCpuBasedMitigations) {
            return $true
        }
    }

    return $false
}

# Check if Hyperthreading is enabled
$cpuInfo = Get-WmiObject -Query "SELECT NumberOfCores,NumberOfLogicalProcessors FROM Win32_Processor"
$numberOfCores = $cpuInfo.NumberOfCores
$numberOfLogicalProcessors = $cpuInfo.NumberOfLogicalProcessors
$hyperThreadingEnabled = $numberOfCores -ne $numberOfLogicalProcessors

# Set expected values based on Hyperthreading status
if ($hyperThreadingEnabled) {
    $FeatureSettingsOverrideExpected = 8388680
    $FeatureSettingsOverrideMaskExpected = 3
} else {
    $FeatureSettingsOverrideExpected = 8396872
    $FeatureSettingsOverrideMaskExpected = 3
}

# Check if Hyper-V is enabled
$hyperVEnabled = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq "Enabled"

if ($hyperVEnabled) {
    $MinVmVersionForCpuBasedMitigationsExpected = "1.0"
} else {
    $MinVmVersionForCpuBasedMitigationsExpected = $null
}

# Check mitigation status
$mitigated = Check-Mitigation -FeatureSettingsOverrideExpected $FeatureSettingsOverrideExpected -FeatureSettingsOverrideMaskExpected $FeatureSettingsOverrideMaskExpected -MinVmVersionForCpuBasedMitigationsExpected $MinVmVersionForCpuBasedMitigationsExpected

if ($mitigated) {
    Write-Output 1
} else {
    Write-Output 0
}
