#region Create a synchronized collection
$SyncedHashTable = [hashtable]::Synchronized(@{})
$SyncedHList = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
#Fist In First Out
$SyncedQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue)) 
#endregion

#region PSJob Sync Variable
Write-Host "PSJobs with a synchronized collection" -ForegroundColor Yellow -BackgroundColor Black
$hash = [hashtable]::Synchronized(@{})
$hash.One = 1
Write-host ('Value of $Hash.One before PSjob is {0}' -f $hash.one) -ForegroundColor Green -BackgroundColor Black
Start-Job -Name TestSync -ScriptBlock {
    Param ($hash)
    $hash.One++
} -ArgumentList $hash | Wait-Job | Out-Null |  Remove-Job
Write-host ('Value of $Hash.One after PSjob is {0}' -f $hash.one) -ForegroundColor Green -BackgroundColor Black
#endregion

#region Runspace Sync Variable
Write-Host "`nRunspaces with a synchronized collection" -ForegroundColor Yellow -BackgroundColor Black
$hash = [hashtable]::Synchronized(@{})
$hash.One = 1
Write-host ('Value of $Hash.One before background runspace is {0}' -f $hash.one) -ForegroundColor Green -BackgroundColor Black
$powershell = [powershell]::Create()
$powershell.Runspace.SessionStateProxy.SetVariable('Hash',$hash)
$powershell.AddScript({
    $hash.one++
}) | Out-Null
$handle = $powershell.BeginInvoke()
While (-Not $handle.IsCompleted) {
    Start-Sleep -Milliseconds 100
}
$powershell.EndInvoke($handle)
$powershell.Dispose()
Write-host ('Value of $Hash.One after background runspace is {0}' -f $hash.one) -ForegroundColor Green -BackgroundColor Black
#endregion

#region Run in Console! -- Adjusting live data -- Run in Console!
$SyncedQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$SyncedHashTable = [hashtable]::Synchronized(@{})
1..50 | ForEach {[void]$SyncedQueue.Enqueue($_)}

#Used to stop the loop
$SyncedHashTable.Flag = $True
#Used to interact with the console
$SyncedHashTable.Host = $Host

$powershell = [powershell]::Create()
$powershell.Runspace.SessionStateProxy.SetVariable('SyncedQueue',$SyncedQueue)
$powershell.Runspace.SessionStateProxy.SetVariable('SyncedHashTable',$SyncedHashTable)
$powershell.AddScript({    
    While ($SyncedHashTable.Flag) {
        #Messing with a Synchronized Collection outside of thread can be risky; more on that later
        If ($SyncedQueue.Count -eq 0) {
            $Count = 0
            $Next = $Null
            $Current = $Null
        } ElseIf ($SyncedQueue.Count -eq 1) {
            $Current = $SyncedQueue.Dequeue()
            $Count = $SyncedQueue.Count
            $Next = $Null   
        } ElseIf ($SyncedQueue.Count -gt 1) {
            $Current = $SyncedQueue.Dequeue()
            $Count = $SyncedQueue.Count
            $Next = $SyncedQueue.Peek()         
        }
        $SyncedHashTable.Host.UI.RawUI.WindowTitle = "Queue Count: {0} | Current Item: {1} | Next Item: {2}" -f $Count, $Current, $Next
        Start-Sleep -Seconds 2
    }
}) | Out-Null
$handle = $powershell.BeginInvoke()

## EXAMPLES TO RUN AFTER KICKED OFF
1..10 | ForEach {$SyncedQueue.Enqueue($_)}
$SyncedQueue.Clear()
1..10 | ForEach {$SyncedQueue.Enqueue($_)}

## WAIT BEFORE RUNNING THIS
$SyncedHashTable.Flag = $False
$powershell.EndInvoke($handle)
$powershell.Runspace.Close()
$powershell.Dispose()
#endregion