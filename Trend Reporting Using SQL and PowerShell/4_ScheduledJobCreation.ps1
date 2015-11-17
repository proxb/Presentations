#Requires -Version 4.0
#Also requires that this be run on Windows Server 2012 for ScheduledTask module
#Code needed to run drive space to sql script 
$Script = "C:\Users\proxb\Desktop\TrendReport\3_ShippingDataToSQL.ps1"
#Ensure it runs at specified time and day 
$TriggerParams = @{
    Daily = $True
    At = '6:00 AM'
}
$Trigger = New-ScheduledTaskTrigger @TriggerParams

$PrincipalParams = @{
    UserId='boe-pc\proxb'
    LogonType = 'Password'
}
$Principal = New-ScheduledTaskPrincipal @PrincipalParams

$TaskSettingParams = @{
    Execute = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    Argument = "-File  $Script"
}
$Action = New-ScheduledTaskAction @TaskSettingParams

$Setting = New-ScheduledTaskSettingsSet

#Create the task with all of the proper configurations 
$Task = New-ScheduledTask -Action  $Action -Trigger  $Trigger -Settings  $Setting -Principal  $Principal

#Complete the scheduled job creation 
$SchedParams = @{
    InputObject = $Task
    User = 'boe-pc\proxb'
    Taskname = "DriveSpaceToSQL1"
}
Register-ScheduledTask @SchedParams -Password (Get-Credential 'boe-pc\proxb').GetNetworkCredential().Password

#We still need to set the interval to every hour
## Run in the console!!!
schtasks.exe /Change /TN DriveSpaceToSQL1 /RI 60 /DU 24:00

#Run the job
Get-ScheduledTask DriveSpaceToSQL1 | Start-ScheduledTask

## ScheduledTasks module comes from Cmdlet Definition XML (CDXML)
## defines the mapping between Windows PowerShell cmdlets and CIM class operations or methods
# http://blogs.technet.com/b/heyscriptingguy/archive/2015/02/03/registry-cmdlets-first-steps-with-cdxml.aspx
# https://msdn.microsoft.com/en-us/library/jj542520(v=vs.85).aspx