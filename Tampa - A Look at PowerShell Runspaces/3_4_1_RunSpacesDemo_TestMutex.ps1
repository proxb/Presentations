[cmdletbinding()]
Param (
    $LogFile = "C:\users\proxb\desktop\testlog.txt",
    $Throttle = 20,
    $Count = 100,
    [switch]$NoMutex
)
 
$Parameters = @{
    LogFile = $LogFile
    NoMutex = $PSBoundParameters.ContainsKey('NoMutex')
    Data = $Null
    Verbose = $PSBoundParameters.ContainsKey('Verbose')
}
 
If ($PSBoundParameters.ContainsKey('Debug')){
    $DebugPreference = 'Continue'
}
 
$RunspacePool = [runspacefactory]::CreateRunspacePool(
    1, #Min Runspaces
    10, #Max Runspaces
    [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault(), #Initial Session State; defines available commands and Language availability
    $host #PowerShell host
)
 
$RunspacePool.Open()
 
$RunspaceJobs = New-Object System.Collections.ArrayList
 If (Test-Path $LogFile) {
    Clear-Content $LogFile
 }
1..$Count | ForEach {
    $PowerShell = [powershell]::Create()
     
    $PowerShell.RunspacePool = $RunspacePool
     
    [void]$PowerShell.AddScript({
        Param(
            $LogFile,
            $NoMutex,
            $Data,
            $Verbose
        )
        If ($Verbose) {
            $VerbosePreference='Continue'
        }
        If (-Not $NoMutex) {
            $mtx = New-Object System.Threading.Mutex($false, "LogMutex")
            Write-Verbose "[$(Get-Date)][PID: $($PID)][TID: $([appdomain]::GetCurrentThreadId())] Requesting mutex!" 
            [void]$mtx.WaitOne()
            Write-Verbose "[$(Get-Date)][PID: $($PID)][TID: $([appdomain]::GetCurrentThreadId())] Recieved mutex!"        
        }
        Try {
            Write-Verbose "[$(Get-Date)][PID: $($PID)][TID: $([appdomain]::GetCurrentThreadId())] Writing data $($Data) to $LogFile" 
            "$($Data)" | Out-File $LogFile -Append
        } Catch {
            Write-Warning $_
        }
        If (-Not $NoMutex) {
            Write-Verbose "[$(Get-Date)][PID: $($PID)][TID: $([appdomain]::GetCurrentThreadId())] Releasing mutex"
            [void]$mtx.ReleaseMutex()
        }
    })
    $Parameters.Data = $_
    [void]$PowerShell.AddParameters($Parameters)
 
    $Handle = $PowerShell.BeginInvoke()
    $temp = '' | Select PowerShell,Handle
    $temp.PowerShell = $PowerShell
    $temp.handle = $Handle
    [void]$RunspaceJobs.Add($Temp)
     
    Write-Debug ("Available Runspaces in RunspacePool: {0}" -f $RunspacePool.GetAvailableRunspaces()) 
    Write-Debug ("Remaining Jobs: {0}" -f @($RunspaceJobs | Where {
        $_.handle.iscompleted -ne 'Completed'
    }).Count)
}
 
#Verify completed
Write-Debug ("Available Runspaces in RunspacePool: {0}" -f $RunspacePool.GetAvailableRunspaces()) 
Write-Debug ("Remaining Jobs: {0}" -f @($RunspaceJobs | Where {
    $_.handle.iscompleted -ne 'Completed'
}).Count)
 
$return = $RunspaceJobs | ForEach {
    $_.powershell.EndInvoke($_.handle);$_.PowerShell.Dispose()
}
$RunspaceJobs.clear()