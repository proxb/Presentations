### Couple of ways to create a Runspace
#region Use [powershell] to create an instance of PowerShell in process with already created runspace

$PS = [powershell]::Create()
$PS | Get-Member
$PS.Runspace
$PS.Runspace.RunspaceConfiguration

#endregion

#region One liners
[powershell]::Create().AddCommand("Get-Location").Invoke()
[powershell]::Create().AddCommand("Get-ChildItem").AddParameter('Filter','*.PS1').AddParameter('Path','C:\Users\Administrator\Desktop\Runspaces_Demo\Runspaces_Demo').Invoke()
# more than 1 parameter needs to use a hashtable with AddParameters() method
$Params = @{
    Path = "C:\users\Administrator\Desktop\Runspaces_Demo\Runspaces_Demo"
    Filter = "*.PS1"
}
[powershell]::Create().AddCommand("Get-ChildItem").AddParameters($Params).Invoke()

#endregion

#region AddScript() method
$PS = [powershell]::Create()

#Notice it returns the PowerShell object; can be sent to $Null
$PS.AddScript({
    Get-Date
})

#Invoke the command
$PS.Invoke()

#endregion

#region AddScript() method -- Adding variable to scriptblock
$PS = [powershell]::Create()

$Param1 = 10
$Param2 = 500
[void]$PS.AddScript({
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
})

#Invoke the command
$PS.Invoke()

$Param1 = 10
$Param2 = 500
{[pscustomobject]@{
    Param1 = $Param1
    Param2 = $Param2
}}.Invoke()

#endregion

#region Supply outside arguments to script block
$Param1 = 10
$Param2 = 500

$PS = [powershell]::Create()

[void]$PS.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddArgument($Param1).AddArgument($Param2)

#Could also use $PS.AddArgument() as well

#Invoke the command
$PS.Invoke()

#endregion

#region Order is important with the .AddArgument() method and the Param() statement in scriptblock
#Supply outside arguments to script block
$Param1 = 10
$Param2 = 500

$PS = [powershell]::Create()

[void]$PS.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddArgument($Param2).AddArgument($Param1)

#Invoke the command
$PS.Invoke()

#endregion

#region Workaround for this is to use AddParameter() instead
$Param1 = 10
$Param2 = 500

$PS = [powershell]::Create()

[void]$PS.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddParameter('Param2',$Param2).AddParameter('Param1',$Param1) #Order won't matter now

#Could also use $PS.AddParameter() as well

#Invoke the command
$PS.Invoke()

#endregion

#region Workaround for this is to use AddParameters() instead

$ParamList = @{
    Param1 = 10
    Param2 = 500
}

$PS = [powershell]::Create()

[void]$PS.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddParameters($ParamList)

#Could also use $PS.AddParameters() as well

#Invoke the command
$PS.Invoke()

#endregion

## Check if running on same Process ID but in different Thread
#region Show currenty ID and Thread for PowerShell.exe
[pscustomobject]@{
    ProcessId = $PID
    Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    TotalThreads = (get-process -id $PID).Threads.count
}

# Show Process ID and thread for new runspace
$PS = [powershell]::Create()
[void]$PS.AddScript({
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        TotalThreads = (get-process -id $PID).Threads.count
    }
})

#Invoke the command
$PS.Invoke()

#Check threads again
[pscustomobject]@{
    ProcessId = $PID
    Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    TotalThreads = (get-process -id $PID).Threads.count
}

#endregion

#region Using PSJobs
[void](Start-Job -Name Thread -ScriptBlock {
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        TotalThreads = (get-process -id $PID).Threads.count
    }
})
[void](Wait-Job -Name Thread)
Receive-Job -Name Thread | Select ProcessID, Thread, TotalThreads
Remove-Job -Name Thread


#endregion

#region Async approach (multithreading)
#region Non-Async
$PS = [powershell]::Create()
#Now let it sleep for a couple seconds
[void]$PS.AddScript({
    Start-Sleep -Seconds 2
    Get-Date
})

#Invoke the command
$PS.Invoke()

#endregion

#region Async
$PS = [powershell]::Create()

#Now let it sleep for a couple seconds
[void]$PS.AddScript({
    Start-Sleep -Seconds 10
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        TotalThreads = (get-process -id $PID).Threads.count
    }
})

#Take the same scriptblock and run it in the background
$Handle = $PS.BeginInvoke()

#Notice IsCompleted property; tells us when command has completed
$Handle

#During this time we have free reign over the console
Get-Process

#Check again
$Handle

#Get results
$PS.EndInvoke($Handle)

#Perform cleanup
$PS.Runspace.Close()
$PS.Dispose()
#endregion

#region Serialized Object PSJob
$Job = Start-Job {Get-Process} 
[void]($job | Wait-Job)
$Data = $job | Receive-Job
Remove-Job $job
#Note the Typename and available methods
$Data | Get-Member
#endregion

#region Live Object Runspace
$PS = [powershell]::Create()

#Now let it sleep for a couple seconds
[void]$PS.AddScript({
    Get-Process
})

#Take the same scriptblock and run it in the background
$Handle = $PS.BeginInvoke()

While (-Not $handle.IsCompleted) {Write-Host "." -NoNewline}

#Get results
$Data = $PS.EndInvoke($Handle)

#Perform cleanup
$PS.Runspace.Close()
$PS.Dispose()

#Note TypeName and available methods
$Data | Get-Member
#endregion

#endregion

#region Use [powershell] to create an instance of PowerShell and [runspacefactory] to create a runspace
## Not as important right now but will be more important with runspace pools
$PS = [powershell]::Create()
$Runspace = [runspacefactory]::CreateRunspace()

$Runspace.ApartmentState = 'STA'
$Runspace.ThreadOptions = 'Default' #Default = UseNewThread on Runspaces and ReuseThread on Runspace Pool

#Open the runspace
$Runspace.Open()

#Add the runspace into the PowerShell instance
$PS.Runspace = $Runspace

#Run like before
[void]$PS.AddScript({
    Start-Sleep -Seconds 2
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        TotalThreads = (get-process -id $PID).Threads.count
    }
})

#Take the same scriptblock and run it in the background
$Handle = $PS.BeginInvoke()

While (-Not $Handle.IsCompleted) {Write-Host '.' -NoNewline;Start-Sleep -Milliseconds 100}

#Get results
$Results = $PS.EndInvoke($Handle)

#Perform cleanup
$PS.Runspace.Close()
$PS.Dispose()

$Results
#endregion