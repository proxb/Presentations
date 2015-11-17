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
            While (-Not $LockTaken) {
                [System.Threading.Monitor]::TryEnter($jobs.SyncRoot,10,[ref]$LockTaken)
                If ($LockTaken) {                      
                    $RSHash.host.ui.WriteVerboseLine('JOBS_RS: Locked Object')              
                    Start-Sleep -Seconds 15
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
                    [System.Threading.Monitor]::Exit($jobs.SyncRoot)   
                    $RSHash.host.ui.WriteVerboseLine('JOBS_RS: Unlocked Object') 
                    Start-Sleep -Seconds 1             
                } Else {
                    $RSHash.host.ui.WriteVerboseLine('JOBS_RS: Unable to take lock on object')
                }                
            } 
            If ($Error) {
                $RSHash.host.ui.WriteWarningLine("Error: $($Error[0].Exception)")
                $Error.clear() 
            } 
        }                    
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $newRunspace
$jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()  
#endregion

$temp = "" | Select-Object PowerShell,Runspace
While ($True) {
    $LockTaken=$False    
    While (-Not $LockTaken) {
        [System.Threading.Monitor]::TryEnter($jobs.SyncRoot,10,[ref]$LockTaken)
        If ($LockTaken) {
            Write-Verbose 'JOBS: Locked object' -Verbose
            $jobs.Add($temp) | Out-Null

            [System.Threading.Monitor]::Exit($jobs.SyncRoot)
            Write-Verbose 'JOBS: Unlocked object' -Verbose
        } Else {Write-Verbose 'JOBS: Unable to take lock on object' -Verbose}
    }
}

$jobCleanup.Flag = $false
$newRunspace.Dispose()
[gc]::Collect()