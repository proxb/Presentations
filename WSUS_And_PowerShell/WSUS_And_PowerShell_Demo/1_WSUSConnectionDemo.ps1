##Assembly needs to be loaded before making connection to WSUS Server
##If running on Windows Server 2012, assembly is loaded when module is loaded; else it needs to be loaded from ProgramFiles
Add-Type -Path "$Env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll"
#OR
Import-Module UpdateServices

##Different ways to connect to WSUS server
[Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer

#Local Connection
[Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

#Remote Connection
[Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer('DC1',$False)

#Remote Connection using different port
[Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer('DC1',$False,'8530')

#Make connection
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer('DC1',$False)

#Check out the connection
$wsus | Select *

##Check out the plethora of methods available
$wsus | Get-Member -MemberType Method