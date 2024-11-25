# Function to calculate battery health
function Get-BatteryHealth {
    # Get battery information from WMI
    $battery = Get-WmiObject -Class Win32_Battery

    if ($battery) {
        foreach ($b in $battery) {
            # Get Design Capacity and Full Charge Capacity
            $designCapacity = $b.DesignCapacity
            $fullChargeCapacity = $b.FullChargeCapacity

            if ($designCapacity -and $fullChargeCapacity) {
                # Calculate battery health as a percentage
                $batteryHealth = ($fullChargeCapacity / $designCapacity) * 100
                [PSCustomObject]@{
                    DeviceName = $env:COMPUTERNAME
                    BatteryName = $b.Name
                    DesignCapacity = $designCapacity
                    FullChargeCapacity = $fullChargeCapacity
                    BatteryHealthPercent = [math]::Round($batteryHealth, 2)
                }
            } else {
                Write-Output "Design or Full Charge Capacity not available for battery on $env:COMPUTERNAME."
            }
        }
    } else {
        Write-Output "No battery information found on $env:COMPUTERNAME."
    }
}

# Run the function and display results
$result = Get-BatteryHealth
if ($result) {
    $result | Format-Table -AutoSize
}
