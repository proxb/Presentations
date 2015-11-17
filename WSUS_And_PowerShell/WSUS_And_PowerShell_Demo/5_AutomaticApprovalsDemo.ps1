#List all Automatic Approvals
$wsus.GetInstallApprovalRules()

#Get the RandomeRule
$rule = $wsus.GetInstallApprovalRules() | Where {
    $_.Name -eq 'SomeRandomRule'
}

#Get the Update Classifications
$rule.GetUpdateClassifications() | Select Title

#Get the Categories
$rule.GetCategories() | Select Type,Title

#Get the Computer Target Groups
$rule.GetComputerTargetGroups()

## Creating an automatic approval rule
#Create New Rule Object
$newRule = $wsus.CreateInstallApprovalRule("2012Servers")
 
##Categories
#Get Categories for Windows Server
$updateCategories = $wsus.GetUpdateCategories() | Where {
  $_.Title -LIKE "Windows Server 2012*"
}
 
#Create collection for Categories
$categoryCollection = New-Object Microsoft.UpdateServices.Administration.UpdateCategoryCollection
$categoryCollection.AddRange($updateCategories)
 
#Add the Categories to the Rule
$newRule.SetCategories($categoryCollection)
 
##Classifications
#Get all Classifications for specific Classifications
$updateClassifications = $wsus.GetUpdateClassifications() | Where {
  $_.Title -Match "Critical Updates|Service Packs|Updates|Security Updates"
}
 
#Create collection for Categories
$classificationCollection = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
$classificationCollection.AddRange($updateClassifications )
 
#Add the Classifications to the Rule
$newRule.SetUpdateClassifications($classificationCollection)
 
##Target Groups
#Get Target Groups required for Rule
$targetGroups = $wsus.GetComputerTargetGroups() | Where {
  $_.Name -Match "All Computers"
}
 
#Create collection for TargetGroups
$targetgroupCollection = New-Object Microsoft.UpdateServices.Administration.ComputerTargetGroupCollection
$targetgroupCollection.AddRange($targetGroups)
 
#Add the Target Groups to the Rule
$newRule.SetComputerTargetGroups($targetgroupCollection)
 
#Finalize the creation of the rule object
$newRule.Enabled = $True
$newRule.Save()

#Run the rule
$newRule.ApplyRule()