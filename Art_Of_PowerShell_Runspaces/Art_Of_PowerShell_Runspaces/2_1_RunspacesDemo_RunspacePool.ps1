#region Runspace Pool
[runspacefactory]::CreateRunspacePool()

$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$RunspacePool = [runspacefactory]::CreateRunspacePool(
    1, #Min Runspaces
    5, #Max Runspaces
    $SessionState, #Initial Session State; defines available commands and Langugage availability
    $host #PowerShell host
)

$PowerShell = [powershell]::Create()

#Uses the RunspacePool vs. Runspace Property
#Cannot have both Runspace and RunspacePool property used; last one applied wins
$PowerShell.RunspacePool = $RunspacePool

#endregion

#region RunspacePool Demo
$DebugPreference = 'Continue'
$Parameters = @{
    Param1 = 'Param1'
    Param2 = 'Param2'
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
        $ThreadID = [appdomain]::GetCurrentThreadId()
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

$return | Group ProcessID | Select Count, Name
$return | Group Thread | Select Count, Name
($return | Group Thread).Count

#endregion RunspacePool Demo

#region Injecting a Variable and using a Custom Function
Function ConvertTo-Hex {
    Param([int]$Number)
    '0x{0:x}' -f $Number
}
$ID=1
$Throttle = 5
[int]$Test = 123498765
$Variable = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'Test',$Test,$Null
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$InitialSessionState.Variables.Add($Variable)

$Definition = Get-Content Function:\ConvertTo-Hex -ErrorAction Stop
$SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList 'ConvertTo-Hex', $Definition
$InitialSessionState.Commands.Add($SessionStateFunction) 
 
$RunspacePool = [runspacefactory]::CreateRunspacePool(1,$Throttle,$InitialSessionState,$Host)
$RunspacePool.Open()
$Jobs = New-Object System.Collections.ArrayList
6..15 | ForEach {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
   
    [void]$PowerShell.AddScript({
        Param ($Number)
        [pscustomobject]@{
            Test = $Test
            Hex = (ConvertTo-Hex -Number $Number)
            Thread = [appdomain]::GetCurrentThreadId()
        }
    }).AddArgument($_)
    $Handle = $PowerShell.BeginInvoke()
   
    [void]$Jobs.Add(
        [pscustomobject]@{
            PowerShell = $PowerShell
            Handle = $Handle
            ID = $ID++
        }
    )
}
 
While (
$Jobs | Where {
    -NOT $_.Handle.IsCompleted
}) {Write-Host "." -NoNewline}
 
$Return = $Jobs | ForEach {    
    $Data = $_.PowerShell.EndInvoke($_.Handle)[0]
    [pscustomobject]@{
        Test = $Data.Test
        Hex = $Data.Hex
        Thread = $Data.Thread
        ID = $_.Id
    }
    $_.PowerShell.Dispose()
}
 
$RunspacePool.Dispose()

$return
$return | Group Thread
#endregion
