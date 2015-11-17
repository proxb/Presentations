#Listing all Clients
$wsus.GetComputerTargets() | Select FullDomainname,IPAddress,OSDescription

#Get client by name
$wsus.GetComputerTargetByName('boe-pc')  | Select FullDomainname,IPAddress,OSDescription

#Search for clients
## This is basically a LIKE statement
$wsus.SearchComputerTargets('c')  | Select FullDomainname,IPAddress,OSDescription

##Get clients via ComputerScope
#Create a computer scope object
$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope

#Find all clients using the computer target scope
$wsus.GetComputerTargets($computerscope)

##Great way to quickly find systems that have not reported for a while or synced
#Last Reported
$computerscope.ToLastReportedStatusTime = (Get-Date).AddMonths(-3)
$wsus.GetComputerTargets($computerscope)

#Last Sync
$computerscope.ToLastSyncTime = (Get-Date).AddMonths(-3)
$wsus.GetComputerTargets($computerscope)


#Removing a Client
$client = $wsus.GetComputerTargetByName('boe-pc')  | Select FullDomainname,IPAddress,OSDescription
$client.Delete()
$wsus.GetComputerTargetByName('boe-pc')  | Select FullDomainname,IPAddress,OSDescription

#View all of the Target Groups 
$wsus.GetComputerTargetGroups()

#Only way to filter is by using Where-Object
$allComputers = $wsus.GetComputerTargetGroups() | Where {
    $_.Name -eq 'All Computers'
}

#List computers in Target Group
$allComputers.GetComputerTargets() | Select FullDomainname,IPAddress,OSDescription

#Creating a new Target Group
$newGroup = $wsus.CreateComputerTargetGroup('Laptops')
$newGroup
$wsus.GetComputerTargetGroups()

#Add a computer to the group
##Requires target client object first
$client = $wsus.GetComputerTargetByName('boe-pc') 
$newGroup.AddComputerTarget($client)

$newGroup.GetComputerTargets()

#Remove a Target Group
$newGroup.Delete()
$wsus.GetComputerTargetGroups()