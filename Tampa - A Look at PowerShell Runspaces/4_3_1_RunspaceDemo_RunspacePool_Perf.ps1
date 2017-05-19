(Measure-Command {
    $RunspacePool = [runspacefactory]::CreateRunspacePool(
        1,
        5, 
        [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault(), 
        $host 
    )
    $Jobs = New-Object System.Collections.ArrayList
    1..15 | ForEach {
        $PowerShell = [powershell]::Create().AddScript({
            Get-WMIObject Win32_OperatingSystem
        })
        $Handle = $PowerShell.BeginInvoke()
        [void]$Jobs.Add(
            [pscustomobject]@{
                PowerShell = $PowerShell
                Handle = $Handle
            }
        )
    }
    While ($Jobs | Where {$_.Handle.IsCompleted}) {}
    $return = $jobs | ForEach {
        $_.powershell.EndInvoke($_.handle);$_.PowerShell.Dispose()
    }
    $jobs.clear()
    $RunspacePool.close()
}).TotalMilliseconds