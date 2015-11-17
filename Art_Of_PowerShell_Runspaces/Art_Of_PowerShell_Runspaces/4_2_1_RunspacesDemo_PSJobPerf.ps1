# PSJob Perf Test

$code = { 
  $begin = Get-Date
  $result = Get-Process
  $end = Get-Date
  
  $begin
  $end
  $result
}

# Start job creation; also used for other reference
$start = Get-Date

$job = Start-Job -ScriptBlock $code
[void](Wait-Job $job)

#Job completed
$completed = Get-Date

$result = Receive-Job $job

#Time to get job results
$received = Get-Date


$spinup = $result[0]
$exit = $result[1]

$timeToLaunch = ($spinup - $start).TotalMilliseconds
$timeToExit = ($completed - $exit).TotalMilliseconds
$timeToRunCommand = ($exit - $spinup).TotalMilliseconds
$timeToReceive = ($received - $completed).TotalMilliseconds
$TotalTime = ($received - $start).TotalMilliseconds


[pscustomobject]@{
    Type = 'PSJob'
    SetUpJob = $timeToLaunch
    RunCode = $timeToRunCommand
    ExitJob = $timeToExit
    RecieveResults = $timeToReceive
    Total = $TotalTime
}
