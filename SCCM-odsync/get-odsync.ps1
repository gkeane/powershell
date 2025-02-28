# *****************************************************
# Example SCCM Script Using odsynclib.dll for OneDrive Status
# *****************************************************

# Determine the folder where the script (and DLL) resides.
# (Requires PowerShell 3.0+ for $PSScriptRoot)
$scriptDir = $PSScriptRoot

# Define the full path to the DLL
$dllPath = Join-Path -Path $scriptDir -ChildPath "odsynclib.dll"

# Ensure the DLL exists
if (-Not (Test-Path $dllPath)) {
    Write-Error "DLL not found at $dllPath"
    exit 1
}

# Define the path for the log file (placed in the same directory)
$logFile = Join-Path -Path $scriptDir -ChildPath "odrive.txt"

# Write the current run date to the log file
"Run Date: $(Get-Date)" | Out-File -FilePath $logFile

# Define the P/Invoke signature for the DLL
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class ODSyncLib {
    [DllImport("ODSyncLib.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    public static extern int GetODSyncStatus(bool IgnoreQuota, [MarshalAs(UnmanagedType.LPWStr)] StringBuilder Result, ulong MaxSize, ref ulong Size);
}
"@

# Initialize variables for the API call
[uint64]$MaxSize = 4096
do {
    $Result = [System.Text.StringBuilder]::new([int]$MaxSize)
    [uint64]$Size = 0
    
    # Call the native function
    $HRESULT = [ODSyncLib]::GetODSyncStatus($false, $Result, $MaxSize, [ref]$Size)

    if ($HRESULT -eq 0) {
        $status = ConvertFrom-Json -InputObject $Result.ToString()
        break
    } 
    elseif ($HRESULT -ne 122) {
        Write-Error "Call to GetODSyncStatus failed. HRESULT: $HRESULT"
        Write-Error "Size: $Size"
        exit 1
    }
    else {
        Write-Warning "Buffer too small. Increasing buffer size to $Size"
        $MaxSize = $Size + 1 # Add 1 for the string terminator
    }
} while($HRESULT -eq 122) # ERROR_INSUFFICIENT_BUFFER

# Optionally, attempt to retrieve a debug item based on the OneDrive environment variable.
try {
    $debugItem = Get-Item -Path "$($env:OneDrive)*"
} catch {
    $debugItem = "OneDrive environment variable not set or path invalid."
}

# Output messages to the console
Write-Output "OneDrive Status:"
Write-Output $status

# If $status is an array (as in the original script where it used $status[0]), log the first element and its type.
if ($status -is [System.Array]) {
    Write-Output "Status Element: $($status[0])"
    Write-Output "Status Element Type: $($status[0].GetType())"
    "Status Element: $($status[0])" | Out-File -FilePath $logFile -Append
    "Status Element Type: $($status[0].GetType())" | Out-File -FilePath $logFile -Append
} else {
    # Otherwise, log the entire status
    "Status: $status" | Out-File -FilePath $logFile -Append
}

# Log the debug item
Write-Output "Debug Item:"
Write-Output $debugItem
"Debug Item: $debugItem" | Out-File -FilePath $logFile -Append
