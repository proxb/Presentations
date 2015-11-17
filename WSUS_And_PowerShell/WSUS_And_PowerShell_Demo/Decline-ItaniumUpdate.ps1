Param (
    [string]$UpdateServer = 'DC1',
    [int]$Port = 80,
    [bool]$Secure = $False
)

If (-Not (Import-Module UpdateServices -PassThru)) {
    Add-Type -Path "$Env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll"
} 

$Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::`
GetUpdateServer($UpdateServer,$Secure,$Port)
 
$approveState = 'Microsoft.UpdateServices.Administration.ApprovedStates' -as [type]
 
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope -Property @{
    TextIncludes = 'itanium'
    ApprovedStates = $approveState::NotApproved,
    $approveState::LatestRevisionApproved,
    $approveState::HasStaleUpdateApprovals
}
 
$wsus.GetUpdates($updateScope) | ForEach {
    Write-Verbose ("Declining {0}" -f $_.Title) -Verbose
    $_.Decline()
}