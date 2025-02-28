$odRoot = $env:OneDriveCommercial
$odDocs = $odRoot+ "\Documents"
$odDesk = $odRoot+ "\Desktop"
$odPics = $odRoot+ "\Pictures"

$odArray = @($odDocs,$odDesk,$odPics)
$out = @()

$OneDriveDocs = "$env:OneDrive\Documents\"
$Shell = (New-Object -ComObject Shell.Application).NameSpace((Split-Path $OneDriveDocs))
write-host "The shell value is: $Shell"
$Status = $Shell.getDetailsOf($Shell.ParseName((Split-Path $OneDriveDocs -Leaf)),303)
write-host "The status is: $Status"
if($status){

    foreach ($directory in $odArray){
        $Shell = (New-Object -ComObject Shell.Application).NameSpace((Split-Path $directory))
        $Status = $Shell.getDetailsOf($Shell.ParseName((Split-Path $directory -Leaf)),303)
        
        $out += $status
    }

    $data = @{
        SyncEvents = @(
            @{
                SyncDate =(get-date).ToString()
                Status=$Status

                Folders=@{
                    Docs = $out[0]
                    Desk = $out[1]
                    Pics = $out[2]
                }
            }
        )
    }
    
    $json = $data|ConvertTo-Json -Depth 4
    $json | Out-File -FilePath 'C:\ProgramData\Quest\KACE\user\ODStatus.json' -Append
    
    }
    
else{
    $data = @{
        SyncEvents = @(
            @{
                SyncDate = (get-date).ToString()
                Status="Paused or Not Syncing"

                Folders=@{
                    Docs = "Paused or Not Syncing"
                    Desk = "Paused or Not Syncing"
                    Pics = "Paused or Not Syncing"
                }
            }
        )
    }
    $json = $data|ConvertTo-Json -Depth 4
    $json | Out-File -FilePath 'C:\ProgramData\Quest\KACE\user\ODStatus.json' -Append

}
$Shell.getDetailsOf($Shell.ParseName((Split-Path $OneDriveDocs -Leaf)),303)