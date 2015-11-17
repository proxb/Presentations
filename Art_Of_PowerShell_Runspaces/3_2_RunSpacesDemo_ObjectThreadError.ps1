$RSHash = [hashtable]::Synchronized(@{})
$jobsList = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
$jobsCleanup = [hashtable]::Synchronized(@{})
$RSHash.host = $host

#region Background runspace to clean up jobs
$jobsCleanup.Flag = $True
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("RSHash",$RSHash)          
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobsCleanup)     
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobsList) 
$jobsCleanup.PowerShell = [PowerShell]::Create().AddScript({
    Do {   
        If ($Jobs.count -gt 0) {            
            Foreach($runspace in $jobs) {
                If ($runspace.Runspace.isCompleted) {
                    $data = $runspace.powershell.EndInvoke($runspace.Runspace) 
                    #$RSHash.host.ui.WriteVerboseLine("Data: $Data")               
                    $runspace.powershell.dispose()
                    $runspace.Runspace = $null
                    $runspace.powershell = $null               
                } 
            }
            #Clean out unused runspace jobs
            $temphash = $jobs.clone()
            $temphash | Where {
                $_.runspace -eq $Null
            } | ForEach {
                $jobs.remove($_)
            }                
            $RSHash.host.ui.WriteVerboseLine("Jobs Left: $($Jobs.count)")                                                     
            If ($Error) {
                $RSHash.host.ui.WriteWarningLine("Error: $($Error[0].Exception)")
                $Error.clear() 
            } 
            Start-Sleep -Seconds 1
        }                   
    } while ($jobCleanup.Flag)
})
$jobsCleanup.PowerShell.Runspace = $newRunspace
$jobsCleanup.Thread = $jobsCleanup.PowerShell.BeginInvoke()  
#endregion


$temp = "" | Select-Object PowerShell,Runspace
While ($True) {
    $jobsList.Add($temp) | Out-Null
}

##Run this last
#Cleanup
$jobsCleanup.Flag = $false
$newRunspace.Dispose()
[gc]::Collect()