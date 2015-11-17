##Finding Failed Installations
#An update scope is needed to accomplish this
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

#Only looking for failed installations
$updateScope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::Failed

#Work through all of the clients to locate a failed installation
$wsus.GetComputerTargets() | ForEach {
    $_.GetUpdateInstallationInfoPerUpdate($UpdateScope) | ForEach {
        $object = [pscustomobject] @{
            Computer = $_.GetComputerTarget().FullDomainName
            Update = $_.GetUpdate().Title
            TargetGroup = $wsus.GetComputerTargetGroup($_.UpdateApprovalTargetGroupId).Name
            InstallationState = $_.UpdateInstallationState
            ApprovalAction = $_.UpdateApprovalAction
        }
        $object.pstypenames.insert(0,"wsus.update.failedinstall")
        $object
    }
}

#--------

##What updates are requiring a reboot?
$computerScope = new-object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computerScope.IncludedInstallationStates ='InstalledPendingReboot'
 
$updateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope 
$updateScope.IncludedInstallationStates = 'InstalledPendingReboot'
 
$computers = $wsus.GetComputerTargets($computerScope) 
ForEach ($Computer in $Computers) { 
    # Show which updates are causing the reboot required for the computer.
    $updatesForReboot = $Computer.GetUpdateInstallationInfoPerUpdate($updateScope)     
    ForEach ($update in $updatesForReboot) {
        $update = $wsus.GetUpdate($update.UpdateId) 
        $object = [pscustomobject] @{
           Update = $update.Title
           Computername = $Computer.FullDomainName
           KB = $update.KnowledgebaseArticles[0]
           SecurityBulletin = $update.SecurityBulletins[0]
        }
        $object.pstypenames.insert(0,"wsus.update.pendingreboot")
        $object
    } 
}

#---------

##Auditing update approvals
#Using GetUpdateApprovals method for this
$wsus.GetUpdateApprovals

#Update scope needed for this
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

$updateScope.FromCreationDate  = (Get-Date).AddMonths(-6)
$updateScope.ToCreationDate = (Get-Date)


#Use the update scope to find all approvals for the last 2 months and list who made the approvals
$wsus.GetUpdateApprovals($updatescope) | ForEach {
    $object = [pscustomobject] @{
        TargetGroup = $_.GetComputerTargetGroup().Name
        Title = ($wsus.GetUpdate([guid]$_.UpdateId.UpdateId.Guid)).Title
        GoLiveTime = $_.GoLiveTime
        AdministratorName = $_.AdministratorName
        Deadline = $_.Deadline
        CreationDate = $_.CreationDate
        Action = $_.Action
    }
    $object.pstypenames.insert(0,"wsus.update.approval")
    $object
} 

#-----

##Get update statistics
#Use the GetSummariesPerComputerTarget method
$wsus.GetSummariesPerComputerTarget

#-Requires both an update scope and a computer scope
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope

$wsus.GetSummariesPerComputerTarget($updateScope,$computerScope) | ForEach {
    $object = [pscustomobject] @{
        Computername = $wsus.GetComputerTarget($_.ComputerTargetID).FullDomainName
        Installed = $_.Installedcount       
        Failed = $_.Failedcount
        Downloaded = $_.DownloadedCount
        NotInstalled = $_.NotInstalledCount
        Unknown = $_.UnknownCount
        PendingReboot = $_.InstalledPendingRebootCount
    }
    $object.pstypenames.insert(0,"wsus.clientupdate.statistics")
    $object
} | Format-Table -AutoSize

#------

##Find number of clients needing a specific update
#Create a computer scope object
$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$Wsus.GetComputerStatus($computerscope,[ Microsoft.UpdateServices.Administration.UpdateSources]::All)

$updates = $wsus.SearchUpdates('Update for Windows Server 2003 (KB938759)')
$update = $updates[0]
$update.GetSummary($computerscope)

##Look at the installation information
$update.GetUpdateInstallationInfoPerComputerTarget($ComputerScope)

#Those guids again...
$update.GetUpdateInstallationInfoPerComputerTarget($ComputerScope) |
Select @{L='Client';E={$wsus.GetComputerTarget(([guid]$_.ComputerTargetId)).FulldomainName}},
@{L='TargetGroup';E={$wsus.GetComputerTargetGroup(([guid]$_.UpdateApprovalTargetGroupId)).Name}},
@{L='Update';E={$wsus.GetUpdate(([guid]$_.UpdateId)).Title}},UpdateInstallationState,UpdateApprovalAction

##Report on updates
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updatescope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved
$updatescope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled
$updatescope.FromArrivalDate = [datetime]"08/13/2013"
$wsus.GetUpdateCount($updateScope)

#Not too useful so lets flesh this out a bit
$wsus.GetUpdateStatus($updatescope,$False)

#Lets find those updates
$wsus.GetUpdates($updatescope) | Select Title

#------

##Update summary report
$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updatescope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved
$updatescope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled
$updatescope.FromArrivalDate = [datetime]"05/13/2013"   
$wsus.GetSummariesPerUpdate($updatescope,$computerscope) |
    Format-Table @{L='UpdateTitle';E={($wsus.GetUpdate([guid]$_.UpdateId)).Title}},
        @{L='NeededCount';E={($_.DownloadedCount + $_.NotInstalledCount)}},
        DownloadedCount,NotApplicableCount,NotInstalledCount,InstalledCount,FailedCount


#--------