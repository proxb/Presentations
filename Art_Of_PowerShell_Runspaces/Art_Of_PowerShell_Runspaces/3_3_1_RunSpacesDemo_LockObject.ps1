$RSHash = [hashtable]::Synchronized(@{})
$jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
$jobCleanup = [hashtable]::Synchronized(@{})
$RSHash.host = $host

#region Background runspace to clean up jobs
$jobCleanup.Flag = $True
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("RSHash",$RSHash)          
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    Do {   
        If ($Jobs.count -gt 0) { 
            $LockTaken = $False
            $RSHash.host.ui.WriteVerboseLine("[$(Get-Date)] JOBS_RS: Attempting lock")
            [System.Threading.Monitor]::Enter($jobs.SyncRoot,[ref]$LockTaken)             
            $RSHash.host.ui.WriteVerboseLine("[$(Get-Date)] JOBS_RS: Locked Object")          
            Start-Sleep -Seconds 5
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
            [System.Threading.Monitor]::Exit($jobs.SyncRoot) 
            $RSHash.host.ui.WriteVerboseLine("[$(Get-Date)] JOBS_RS: Unlocked Object")             
            $RSHash.host.ui.WriteVerboseLine("[$(Get-Date)] JOBS_RS: Jobs Left: $($Jobs.count)")                                                     
            If ($Error) {
                $RSHash.host.ui.WriteWarningLine("Error: $($Error[0].Exception)")
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
    $LockTaken = $False
    Write-Verbose "[$(Get-Date)] JOBS: Attempting lock" -Verbose
    [System.Threading.Monitor]::Enter($jobs.SyncRoot,[ref]$LockTaken) 
    Write-Verbose "[$(Get-Date)] JOBS: Locked object" -Verbose
    $jobs.Add($temp) | Out-Null    
    [System.Threading.Monitor]::Exit($jobs.SyncRoot)
    Write-Verbose "[$(Get-Date)] JOBS: Unlocked object" -Verbose
}

#Cleanup
$jobCleanup.Flag = $false
$newRunspace.Dispose()
[gc]::Collect()