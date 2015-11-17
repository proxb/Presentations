## RUN IN CONSOLE


Measure-Command {
    [cmdletbinding()]
    Param (
        [Int32]$MaxJobs = 5,
        [parameter(ValueFromPipeLine=$True,ValueFromPipeLineByPropertyName=$True)]
        [string[]]$Items = (1..15)
    )
    Function Global:Get-WMIInfo { 
        $VerbosePreference = 'silentlycontinue'
        If ($queue.count -gt 0) {
            Write-Verbose ("Queue Count: {0}" -f $queue.count)   
            $Computer = $queue.Dequeue()
            $j = Start-Job -Name $Computer -ScriptBlock {
                Get-WmiObject Win32_OperatingSystem
            }
            Register-ObjectEvent -InputObject $j -EventName StateChanged -Action {
                #Set verbose to continue to see the output on the screen
                $VerbosePreference = 'continue'
                $serverupdate = $eventsubscriber.sourceobject.name      
                $Global:Data += Receive-Job -Job $eventsubscriber.sourceobject
                #Write-Verbose "Removing: $($eventsubscriber.sourceobject.Name)"           
                Remove-Job -Job $eventsubscriber.sourceobject
                #Write-Verbose "Unregistering: $($eventsubscriber.SourceIdentifier)"
                Unregister-Event $eventsubscriber.SourceIdentifier
                #Write-Verbose "Removing: $($eventsubscriber.SourceIdentifier)"
                Remove-Job -Name $eventsubscriber.SourceIdentifier
                Remove-Variable results        
                If ($queue.count -gt 0 -OR (Get-Job)) {
                    #Write-Verbose "Running job"
                    Get-WMIInfo
                }           
            } | Out-Null
            #Write-Verbose "Created Event for $($J.Name)"
        }
    }

    #Define report
    [string[]]$Global:Data = @()
    #Queue the items up
    $Global:queue = [System.Collections.Queue]::Synchronized( (New-Object System.Collections.Queue) )
    foreach($item in $Items) {
        #Write-Verbose "Adding $item to queue"
        $queue.Enqueue($item)
    }
    If ($queue.count -lt $maxjobs) {
        $maxjobs = $queue.count
    }
    # Start up to the max number of concurrent jobs
    # Each job will take care of running the rest
    for( $i = 0; $i -lt $MaxJobs; $i++ ) {
        Get-WMIInfo
    } 
    While ((Get-Job).Count -gt 0) {Start-Sleep -Milliseconds 10}
}

