# Replace these placeholders with your actual values
$wsusServerUrl = "https://nss-wsus.win.udel.edu"
$apiKey = "<API_KEY>"
$targetGroup = "BlockWin11"

# Create the authorization header
$headers = @{
    "Authorization" = "Bearer $apiKey"
}

# Build the API endpoint URL
$endpoint = "$wsusServerUrl/api/computergroups"

# Query the WSUS server for computer groups
$response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get

if ($response) {
    $group = $response | Where-Object { $_.Name -eq $targetGroup }

    if ($group) {
        $groupId = $group.Id
        $updateEndpoint = "$wsusServerUrl/api/updates?updateApproveState=1&updateComputerGroupId=$groupId"

        # Query the WSUS server for updates in the specified group
        $updateResponse = Invoke-RestMethod -Uri $updateEndpoint -Headers $headers -Method Get

        if ($updateResponse) {
            Write-Host "Updates available in group '$targetGroup':"
            foreach ($update in $updateResponse) {
                Write-Host "Update Title: $($update.Title)"
                Write-Host "Update ID: $($update.Id)"
                Write-Host "----------------------------------"
            }
        } else {
            Write-Host "No updates found in group '$targetGroup'."
        }
    } else {
        Write-Host "Group '$targetGroup' not found."
    }
} else {
    Write-Host "Failed to retrieve computer groups from WSUS."
}