#Show all updates on the WSUS Server
measure-command {$wsus.GetUpdates()}

#Locate some SQL Updates
$updates = $wsus.SearchUpdates('Server 2012')

##Show file structure real fast
#Dig into the object to find where the install files are located
$updates[0].GetInstallableItems()
$updates[0].GetInstallableItems().Files

#Specify a time range using the UpdateScope Object
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
#Dig deeper into this object to find what is settable
$updateScope | Get-Member -Type Property | Where {
    $_.Definition -match "set;"
}
#Approval States; Looking for anything not approved/declined
[enum]::GetNames('Microsoft.UpdateServices.Administration.ApprovedStates')
$updateScope.ApprovedStates = 'NotApproved'

#Installation State; looking for anything that needs an update
[enum]::GetNames('Microsoft.UpdateServices.Administration.UpdateInstallationStates')
$updateScope.IncludedInstallationStates = 'NotInstalled'
<#
    ArrivalTime -> When patch was downloaded
    Creation -> When patch was authored (Created)
#>
$updateScope.FromArrivalDate = (Get-Date).AddDays(-31)
$updates = $wsus.GetUpdates($updateScope)

#State value from some updates (NotNeeded) doesn't really tell the truth
#NotNeeded only valid if HostBinariesOnMicrosoftUpdate -eq $True
$Wsus.GetConfiguration() | Select HostBinariesOnMicrosoftUpdate


##Approving Updates
#Sometimes an update may require a license agreement
If ($updates[0].RequiresLicenseAgreementAcceptance) {
    $updates[0].AcceptLicenseAgreement()
}

#Approving an update
$updates[0].Approve

#what are the install actions?
[enum]::GetNames('Microsoft.UpdateServices.Administration.UpdateApprovalAction')

#Approve update at the root
$updates[0].Approve('Install')

#Approve update for a specific Target Group
#First we need the group
$Group = $wsus.GetComputerTargetGroups() | Where {
    $_.Name -eq 'Windows 2012'
}

##Better approach would be to create hashtable so you aren't running the same method each time
$TargetGroups = @{}
$wsus.GetComputerTargetGroups() | ForEach {
    $TargetGroups[$_.Name] = $_
}

#Now we can approve for that group
$updates[0].Approve($TargetGroup['Windows 2012'],'Install')

#Approving updates for multiple target groups
$Groups = 'Servers','Windows 2012'
ForEach ($update in $updates){ 
    ForEach ($group in $groups) {
        Write-Verbose ("Approving {0} on {1}" -f $update.title,$TargetGroup[$group])
        $update.Approve($TargetGroup[$Group],'Install')
    }
}

##Declining Updates
$updates[0].Decline()