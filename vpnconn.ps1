# Function to get the current IP address on the VPN connection
function Get-VpnIpAddress {
    $vpnInterface = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -like '*AnyConnect*' }
    if ($vpnInterface) {
        $vpnIpAddress = Get-NetIPAddress -InterfaceIndex $vpnInterface.ifIndex | Where-Object { $_.AddressFamily -eq 'IPv4' }
        if ($vpnIpAddress) {
            return $vpnIpAddress.IPAddress
        } else {
            return "No IPv4 address found for the VPN connection."
        }
    } else {
        return "No active VPN connection found."
    }
}

# Get and print the current IP address on the VPN connection
$vpnIpAddress = Get-VpnIpAddress
Write-Host "Current VPN IP Address: $vpnIpAddress"

# Embedded CSV data
$csvData = @"
IP Address,Port,Type
10.8.16.45,80,tcp
10.8.16.45,135,tcp
10.8.16.45,2222,tcp
10.8.16.45,2222,udp
10.8.16.45,44818,tcp
10.8.16.45,44818,udp
10.8.16.44,445,tcp
10.8.16.44,3389,tcp
10.8.16.44,5900,tcp
10.8.16.44,5901,tcp
10.8.16.44,5902,tcp
10.8.16.43,445,tcp
10.8.16.43,3389,tcp
10.8.16.43,5900,tcp
10.8.16.43,5901,tcp
10.8.16.43,5902,tcp
10.8.16.39,445,tcp
10.8.16.39,5000,tcp
10.8.16.39,5001,tcp
"@

# Convert the embedded CSV data to an array of objects
$portsList = $csvData | ConvertFrom-Csv

# Initialize an array to store the results
$results = @()

foreach ($entry in $portsList) {
    $ip = $entry.'IP Address'
    $port = $entry.Port
    $protocol = $entry.Type

    # Skip empty IP entries
    if (-not $ip) {
        continue
    }

    # Test the connection
    Write-Host "Testing IP: $ip, Port: $port, Protocol: $protocol..."
    if ($protocol -match "tcp") {
        $testResult = Test-NetConnection -ComputerName $ip -Port $port -InformationLevel "Detailed"
    } elseif ($protocol -match "udp") {
        # Test-NetConnection does not support UDP, so using Test-Connection as a workaround for simplicity
        $testResult = Test-Connection -ComputerName $ip -Count 1
    } else {
        $testResult = $null
    }

    # Determine the status
    if ($testResult -ne $null) {
        if ($protocol -match "tcp" -and $testResult.TcpTestSucceeded) {
            $status = "Open"
        } elseif ($protocol -match "udp" -and $testResult.StatusCode -eq 0) {
            $status = "Open"
        } else {
            $status = "Closed"
        }
    } else {
        $status = "Filtered"
    }

    # Store the result
    $results += [PSCustomObject]@{
        IP       = $ip
        Port     = $port
        Protocol = $protocol
        Status   = $status
    }
}

$vpnIpAddress = Get-VpnIpAddress
Write-Host "Current VPN IP Address: $vpnIpAddress"
# Output the results to the console
$results | Format-Table -AutoSize

Write-Host "Port scanning completed."
