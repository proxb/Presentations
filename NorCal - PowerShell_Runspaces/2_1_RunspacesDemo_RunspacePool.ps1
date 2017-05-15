#region Runspace Pool
[runspacefactory]::CreateRunspacePool

$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$RunspacePool = [runspacefactory]::CreateRunspacePool(
    1, #Min Runspaces
    5, #Max Runspaces
    $SessionState, #Initial Session State; defines available commands and Langugage availability
    $host #PowerShell host
)

$PS = [powershell]::Create()

#Uses the RunspacePool vs. Runspace Property
#Cannot have both Runspace and RunspacePool property used; last one applied wins
$PS.RunspacePool = $RunspacePool

#endregion

#region RunspacePool Demo
$DebugPreference = 'Continue'
$Parameters = @{
    Param1 = 10
    Param2=200
}

$RunspacePool = [runspacefactory]::CreateRunspacePool(
    1, #Min Runspaces
    10, #Max Runspaces
    [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault(), #Initial Session State; defines available commands and Language availability
    $host #PowerShell host
)

$RunSpacePool.ApartmentState = 'STA'
$RunspacePool.Open()

$jobs = New-Object System.Collections.ArrayList

1..50 | ForEach {
    $PowerShell = [powershell]::Create()
    
    $PowerShell.RunspacePool = $RunspacePool
    
    [void]$PowerShell.AddScript({
        Param (
            $Param1,
            $Param2
        )
        $ThreadID = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        Write-Verbose "ThreadID: Beginning $ThreadID" -Verbose
        $sleep = Get-Random (1..5)        
        [pscustomobject]@{
            Param1 = $param1
            Param2 = $param2
            Thread = $ThreadID
            ProcessID = $PID
            SleepTime = $Sleep
        }  
        Start-Sleep -Seconds $sleep
        Write-Verbose "ThreadID: Ending $ThreadID" -Verbose
    })

    [void]$PowerShell.AddParameters($Parameters)

    $Handle = $PowerShell.BeginInvoke()
    $temp = '' | Select PowerShell,Handle
    $temp.PowerShell = $PowerShell
    $temp.handle = $Handle
    [void]$jobs.Add($Temp)
    
    Write-Debug ("Available Runspaces in RunspacePool: {0}" -f $RunspacePool.GetAvailableRunspaces()) 
    Write-Debug ("Remaining Jobs: {0}" -f @($jobs | Where {
        $_.handle.iscompleted -ne 'Completed'
    }).Count)
}

#Verify completed
Write-Debug ("Available Runspaces in RunspacePool: {0}" -f $RunspacePool.GetAvailableRunspaces()) 
Write-Debug ("Remaining Jobs: {0}" -f @($jobs | Where {
    $_.handle.iscompleted -ne 'Completed'
}).Count)

$return = $jobs | ForEach {
    $_.powershell.EndInvoke($_.handle)
    $_.PowerShell.Dispose()
}
$jobs.clear()

$return  | Format-Table

$return | Group Thread | Select Count, Name
$return | Group ProcessID | Select Count, Name

#endregion RunspacePool Demo

#region Injected Variable
$Throttle = 5
[int]$Test = 06071980
$Variable = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Test',$Test,$Null
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$InitialSessionState.Variables.Add($Variable)
 
$RunspacePool = [runspacefactory]::CreateRunspacePool(1,$Throttle,$InitialSessionState,$Host)
$RunspacePool.Open()
$Jobs = New-Object System.Collections.ArrayList
1..10 | ForEach {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
   
    [void]$PowerShell.AddScript({
        $Test
    })
    $Handle = $PowerShell.BeginInvoke()
   
    [void]$Jobs.Add(
        [pscustomobject]@{
            PowerShell = $PowerShell
            Handle = $Handle
            GUID = [guid]::NewGuid().ToString()
            ID = $ID++
        }
    )
}
 
While (
$Jobs | Where {
    -NOT $_.Handle.IsCompleted
}) {Write-Host "." -NoNewline}
 
$Jobs | ForEach {    
    [pscustomobject]@{
        Data = $_.PowerShell.EndInvoke($_.Handle)[0]
        ID = $_.Id
        GUID = $_.guid
    }
    $_.PowerShell.Dispose()
}
 
$RunspacePool.Dispose()
#endregion
