### Couple of ways to create a Runspace
#region Use [powershell] to create an instance of PowerShell in process with already created runspace
$PowerShell = [powershell]::Create()
$PowerShell | Get-Member
$PowerShell.Runspace
$PowerShell.Runspace | Get-Member
$PowerShell.Runspace.RunspaceConfiguration
$PowerShell.Runspace.RunspaceConfiguration | Get-Member
$PowerShell.Dispose()
#endregion

#region One liners
[powershell]::Create().AddCommand("Get-Location").Invoke()
[powershell]::Create().AddCommand("Get-ChildItem").AddParameter('Filter','*.PS1').
AddParameter('Path','C:\Users\boepr\desktop\Art_Of_PowerShell_Runspaces').Invoke()

# more than 1 parameter needs to use a hashtable with AddParameters() method
$Params = @{
    Path = "C:\Users\boepr\desktop\Art_Of_PowerShell_Runspaces"
    Filter = "*.PS1"
}
[powershell]::Create().AddCommand("Get-ChildItem").AddParameters($Params).Invoke()

#endregion

#region AddScript() method
$PowerShell = [powershell]::Create()

#Notice it returns the PowerShell object; can be sent to $Null
$PowerShell.AddScript({
    Get-Date
})

#View the commands
$PowerShell.Commands.Commands

#Invoke the command
$PowerShell.Invoke()

#endregion

#region AddScript() method -- Adding variable to scriptblock
$PowerShell = [powershell]::Create()
$Param1 = 'Param1'
$Param2 = 'Param2'
[void]$PowerShell.AddScript({
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
})

#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()
#endregion

#region Supply outside arguments to script block
$Param1 = 'Param1'
$Param2 = 'Param2'

$PowerShell = [powershell]::Create()

[void]$PowerShell.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddArgument($Param1).AddArgument($Param2)

#Could also use $PowerShell.AddArgument() as well

$PowerShell.Commands.Commands.parameters

#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()
#endregion

#region Order is important with the .AddArgument() method and the Param() statement in scriptblock
#Supply outside arguments to script block
$Param1 = 'Param1'
$Param2 = 'Param2'

$PowerShell = [powershell]::Create()

[void]$PowerShell.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddArgument($Param2).AddArgument($Param1)

$PowerShell.Commands.Commands.parameters

#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()
#endregion

#region Workaround for this is to use AddParameter() instead
$Param1 = 'Param1'
$Param2 = 'Param2'

$PowerShell = [powershell]::Create()

[void]$PowerShell.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddParameter('Param2',$Param2).AddParameter('Param1',$Param1) #Order won't matter now

#Could also use $PowerShell.AddParameter() as well

$PowerShell.Commands.Commands.parameters

#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()

#endregion

#region Workaround for this is to use AddParameters() instead

$ParamList = @{
    Param1 = 'Param1'
    Param2 = 'Param2'
}

$PowerShell = [powershell]::Create()

[void]$PowerShell.AddScript({
    Param ($Param1, $Param2)
    [pscustomobject]@{
        Param1 = $Param1
        Param2 = $Param2
    }
}).AddParameters($ParamList)

#Could also use $PowerShell.AddParameters() as well

#Invoke the command
$PowerShell.Invoke()

#endregion

#region Show currenty ID and Thread for PowerShell.exe
## Check if running on same Process ID but in different Thread
[pscustomobject]@{
    Type = 'Standard'
    ProcessId = $PID
    Thread = [appdomain]::GetCurrentThreadId()
    TotalThreads = (get-process -id $PID).Threads.count
}

# Show Process ID and thread for new runspace
$PowerShell = [powershell]::Create()
[void]$PowerShell.AddScript({
    [pscustomobject]@{
        Type = 'Runspace'
        ProcessId = $PID
        Thread = [appdomain]::GetCurrentThreadId()
        TotalThreads = (get-process -id $PID).Threads.count
    }
})
#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()

#Check threads again
[pscustomobject]@{
    Type = 'Standard'
    ProcessId = $PID
    Thread = [appdomain]::GetCurrentThreadId()
    TotalThreads = (get-process -id $PID).Threads.count
}
#region Using PSJobs
[void](Start-Job -Name Thread -ScriptBlock {
    [pscustomobject]@{
        Type = 'PSJob'
        ProcessId = $PID
        Thread = [appdomain]::GetCurrentThreadId()
        TotalThreads = (get-process -id $PID).Threads.count
    }
})
[void](Wait-Job -Name Thread)
Receive-Job -Name Thread | Select Type, ProcessID, Thread, TotalThreads
Remove-Job -Name Thread
#endregion
#endregion

##Now onto the real fun of Runspaces!
#region Async approach (multithreading)
#region Non-Async
$PowerShell = [powershell]::Create()
#Now let it sleep for a couple seconds
[void]$PowerShell.AddScript({
    Start-Sleep -Seconds 2
    Get-Date
})

#Invoke the command
$PowerShell.Invoke()
$PowerShell.Dispose()
#endregion

#region Async
$PowerShell = [powershell]::Create()

#Now let it sleep for a couple seconds
[void]$PowerShell.AddScript({
    Start-Sleep -Seconds 10
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [appdomain]::GetCurrentThreadId()
        TotalThreads = (get-process -id $PID).Threads.count
    }
})

#Take the same scriptblock and run it in the background
# System.Management.Automation.PowerShellAsyncResult
$Handle = $PowerShell.BeginInvoke()

#Notice IsCompleted property; tells us when command has completed
$Handle

#During this time we have free reign over the console
(Get-Process -id $PID).Threads | Select Id, ThreadState, StartTime

#Check again
$Handle

#Get results
#EndInvoke waits for a pending async call and returns the results, if any
$PowerShell.EndInvoke($Handle)

#Perform cleanup
$PowerShell.Dispose()
#endregion

#region Serialized Object PSJob
$Process = Get-Process
$Process | Get-Member

$Job = Start-Job {Get-Process} 
[void]($job | Wait-Job)
$Data = $job | Receive-Job
Remove-Job $job

#Note the Typename and available methods compared to $Process
$Data | Get-Member

#View the methods
$Data | Get-Member -Type Method
$Process | Get-Member -Type Method
#endregion

#region Live Object Runspace
$PowerShell = [powershell]::Create()

#Now let it sleep for a couple seconds
[void]$PowerShell.AddScript({
    Get-Process
    Start-Sleep -Seconds 2
})

#Take the same scriptblock and run it in the background
$Handle = $PowerShell.BeginInvoke()

While (-Not $handle.IsCompleted) {
    Write-Host "." -NoNewline;Start-Sleep -Milliseconds 100
}

#Get results
$Data = $PowerShell.EndInvoke($Handle)

#Perform cleanup
$PowerShell.Runspace.Close()
$PowerShell.Dispose()

#Note TypeName and available methods
$Data | Get-Member
#endregion

#endregion

#region Use [powershell] to create an instance of PowerShell and [runspacefactory] to create a runspace
## Not as important right now but will be more important with runspace pools
$PowerShell = [powershell]::Create()
$Runspace = [runspacefactory]::CreateRunspace()

$Runspace.ApartmentState = 'STA'
#Default = UseNewThread on Runspaces and ReuseThread on Runspace Pool
$Runspace.ThreadOptions = 'Default' 

#Open the runspace
$Runspace.Open()

#Add the runspace into the PowerShell instance
$PowerShell.Runspace = $Runspace

#Run like before
[void]$PowerShell.AddScript({
    Start-Sleep -Seconds 2
    [pscustomobject]@{
        ProcessId = $PID
        Thread = [appdomain]::GetCurrentThreadId()
        TotalThreads = (get-process -id $PID).Threads.count
    }
})

#Take the same scriptblock and run it in the background
$Handle = $PowerShell.BeginInvoke()

While (-Not $Handle.IsCompleted) {
    Write-Host '.' -NoNewline;Start-Sleep -Milliseconds 100
}

#Get results
$Results = $PowerShell.EndInvoke($Handle)

#Perform cleanup
$PowerShell.Runspace.Close()
$PowerShell.Dispose()

$Results
#endregion

#region Adding a Module
$PowerShell = [powershell]::Create()
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$Runspace = [runspacefactory]::CreateRunspace($Host,$SessionState)
$Runspace.Open()
$SessionState.ImportPSModule(@('IEFavorites','Pester','PoshPrivilege'))
$PowerShell.Runspace = $Runspace
[void]$PowerShell.AddScript({
    @{
        IEFavorites = (Get-IEFavorite)
        Privileges = (Get-Privilege)
    }
})
$Return = $PowerShell.Invoke()
$PowerShell.Dispose()
#endregion Adding a Module

#region Adding a custom function
Function ConvertTo-Hex {
    Param([int]$Number)
    '0x{0:x}' -f $Number
}
$PowerShell = [powershell]::Create()
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

#Add the function --Must happen before we create the runspace--
$Definition = Get-Content Function:\ConvertTo-Hex -ErrorAction Stop
$SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList 'ConvertTo-Hex', $Definition
$SessionState.Commands.Add($SessionStateFunction) 

$Runspace = [runspacefactory]::CreateRunspace($Host,$SessionState)
$Runspace.Open()
$PowerShell.Runspace = $Runspace

#Inject data into variable
$Runspace.SessionStateProxy.SetVariable('Number','25')
[void]$PowerShell.AddScript({
    ConvertTo-Hex -Number $Number
})
$PowerShell.Invoke()
$PowerShell.Dispose()
#endregion Adding a custom function