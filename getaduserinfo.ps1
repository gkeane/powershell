
Import-Module Microsoft.Graph.Reports
Connect-mgGraph -Scopes 'User.Read.All'

Get-MgReportOffice365ActivationUserDetail -outfile file.csv
