$UIHash = [hashtable]::Synchronized(@{})
$jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
$jobCleanup = [hashtable]::Synchronized(@{})
$UIHash.host = $host

#region Background runspace to clean up jobs
$jobCleanup.Flag = $True
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("uiHash",$uiHash)          
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    Do {   
        If ($Jobs.count -gt 0) {            
            Foreach($runspace in $jobs) {
                If ($runspace.Runspace.isCompleted) {
                    $data = $runspace.powershell.EndInvoke($runspace.Runspace) 
                    #$UIHash.host.ui.WriteVerboseLine("Data: $Data")               
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
            $UIHash.host.ui.WriteVerboseLine("Jobs Left: $($Jobs.count)")                                                     
            If ($Error) {
                $UIHash.host.ui.WriteWarningLine("Error: $($Error[0].Exception)")
                $Error.clear() 
            } 
            Start-Sleep -Seconds 1
        }                   
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $newRunspace
$jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()  
#endregion


$temp = "" | Select-Object PowerShell,Runspace
While ($True) {
    $jobs.Add($temp) | Out-Null
}

#Cleanup
$jobCleanup.Flag = $false
$newRunspace.Dispose()
[gc]::Collect()