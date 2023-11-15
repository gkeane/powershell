Import-Module ActiveDirectory
# Specify inactivity range value below
$DaysInactive = 90
# $time variable converts $DaysInactive to LastLogonTimeStamp property format for the -Filter switch to work

$time = (Get-Date).Adddays(-($DaysInactive))

# Identify inactive computer accounts

Get-ADComputer -Filter {LastLogonTimeStamp -lt $time} -ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate