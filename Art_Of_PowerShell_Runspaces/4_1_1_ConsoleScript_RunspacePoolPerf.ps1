## RUN THIS SCRIPT IN CONSOLE!!

#region RunspacePool Demo
$Script:StartTime = Get-Date
$Script:StartingMemory = (Get-Process -Id $PID).WS /1MB
Write-Verbose ("Starting Memory: {0:N}" -f $Script:StartingMemory) -Verbose
$Script:PeakMemory = 0
$Script:PeakMemoryUsed = 0
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

1..100 | ForEach {
    $PowerShell = [powershell]::Create()
    
    $PowerShell.RunspacePool = $RunspacePool
    
    [void]$PowerShell.AddScript({
        Param (
            $Param1,
            $Param2
        )
        $ThreadID = [System.Threading.Thread]::CurrentThread.ManagedThreadId      
        [pscustomobject]@{
            Param1 = $param1
            Param2 = $param2
            Thread = $ThreadID
            ProcessID = $PID
            SleepTime = $Sleep
        } 
        ## Remove comment to show grouping of Threads after first demo 
        Start-Sleep -Seconds (Get-Random (1..5))
    })

    [void]$PowerShell.AddParameters($Parameters)

    $Handle = $PowerShell.BeginInvoke()
    $temp = '' | Select PowerShell,Handle
    $temp.PowerShell = $PowerShell
    $temp.handle = $Handle
    [void]$jobs.Add($Temp)

    $Process = Get-Process -Id $PID
    $Memory = $Process.WS /1MB
    $Used = ($Memory - $Script:StartingMemory)
    If ($Memory -gt $Script:PeakMemory) {
        $Script:PeakMemory = $Memory
    }
    If ($Used -gt $Script:PeakMemoryUsed) {
        $Script:PeakMemoryUsed = $Used
    }
    $host.ui.RawUI.WindowTitle = "Available Runspaces: {0} | Jobs Remaining: {1} | Threads: {2} | CurrentMem(MB): {3:N} | UsedMem(MB): {4:N} | PeakMem(MB): {5:N} | PeakMemUsed(MB): {6:N}" -f $RunspacePool.GetAvailableRunspaces(),
    @($jobs | Where {
        $_.handle.iscompleted -ne 'Completed'
    }).Count,
    $Process.Threads.Count,
    ($Process.WS / 1MB),
    ($Memory - $Script:StartingMemory),
    $Script:PeakMemory,
    $Script:PeakMemoryUsed

}

Do {
    Write-Host "." -NoNewline
    $Process = Get-Process -Id $PID
    $Memory = $Process.WS /1MB
    $Used = ($Memory - $Script:StartingMemory)
    If ($Memory -gt $Script:PeakMemory) {
        $Script:PeakMemory = $Memory
    }
    If ($Used -gt $Script:PeakMemoryUsed) {
        $Script:PeakMemoryUsed = $Used
    }
    $host.ui.RawUI.WindowTitle = "Available Runspaces: {0} | Jobs Remaining: {1} | Threads: {2} | CurrentMem(MB): {3:N} | UsedMem(MB): {4:N} | PeakMem(MB): {5:N} | PeakMemUsed(MB): {6:N}" -f $RunspacePool.GetAvailableRunspaces(),
    @($jobs | Where {
        $_.handle.iscompleted -ne 'Completed'
    }).Count,
    $Process.Threads.Count,
    ($Process.WS / 1MB),
    ($Memory - $Script:StartingMemory),
    $Script:PeakMemory,
    $Script:PeakMemoryUsed
    Start-Sleep -Milliseconds 100
} While (@($jobs | Where {$_.handle.iscompleted -ne 'Completed'}).Count -ne 0)

$jobs | ForEach {
    $_.powershell.EndInvoke($_.handle)
    $_.PowerShell.Dispose()
} | Group Thread | Select Count, Name
$Finished = ((Get-Date) - $Script:StartTime).totalmilliseconds
$RunspacePool.Close()
Remove-Variable jobs
[gc]::Collect()

$Process = Get-Process -Id $PID
$Memory = $Process.WS /1MB
$Used = ($Memory - $Script:StartingMemory)
If ($Memory -gt $Script:PeakMemory) {
    $Script:PeakMemory = $Memory
}
If ($Used -gt $Script:PeakMemoryUsed) {
    $Script:PeakMemoryUsed = $Used
}
$host.ui.RawUI.WindowTitle = "Available Runspaces: {0} | Jobs Remaining: {1} | Threads: {2} | CurrentMem(MB): {3:N} | UsedMem(MB): {4:N} | PeakMem(MB): {5:N} | PeakMemUsed(MB): {6:N}" -f 0,
0,
$Process.Threads.Count,
($Process.WS / 1MB),
($Memory - $Script:StartingMemory),
$Script:PeakMemory,
$Script:PeakMemoryUsed
Write-Host "`n"
Write-Verbose ("Finished in: {0} milliseconds" -f $Finished) -Verbose