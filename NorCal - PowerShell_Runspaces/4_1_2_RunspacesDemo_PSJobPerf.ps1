﻿#region Track WS Memory -- RUN THIS PORTION IN CONSOLE!
$Script:PeakMemory = 0
While ($True) {
    Clear-Host
    $Data = Get-Process -Name powershell | Where ID -notmatch "$PID|3084" | #Other PID should be from other console
    Select @{L='WS(MB)';E={"{0:N}" -f ($_.WS/1MB)}},ID,ProcessName,@{L='ThreadCount';E={$_.Threads.Count}}
    $Data | Format-Table -AutoSize
    $Memory = ([int]($Data | Measure-Object -Property "WS(MB)" -Sum).Sum)
    If ($Memory -gt $Script:PeakMemory) {
        $Script:PeakMemory = $Memory
    }
    Write-Host ("`nTotal Memory (MB): {0}" -f $Memory) -ForegroundColor Yellow -BackgroundColor Black
    Write-Host ("Peak Memory (MB): {0}" -f $Script:PeakMemory) -ForegroundColor Yellow -BackgroundColor Black
    Start-sleep -Seconds 2
}
#endregion

#region Measure PSJob Memory -- RUN THIS FROM A SECOND CONSOLE SESSION
$Param1 = 10
$Param2=200
$Jobs = 1..10 | ForEach {
    start-job {
        Param (
            $Param1,
            $Param2
        )
        $Sleep = Get-Random -Input (1..5)
        Start-Sleep -Seconds $Sleep
        $ThreadID = [System.Threading.Thread]::CurrentThread.ManagedThreadId       
        [pscustomobject]@{
            Param1 = $param1
            Param2 = $param2
            Thread = $ThreadID
            ProcessID = $PID
            SleepTime = $Sleep
        }     
    } -ArgumentList $param1, $Param2
}

$jobs | wait-job | Remove-Job -Force
#endregion
 
#region Measure PSJob Time -- RUN THIS FROM A SECOND CONSOLE SESSION
(Measure-Command {
    $Param1 = 10
    $Param2=200
    1..10 | ForEach {
        start-job {
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
            }     
        } -ArgumentList $param1, $Param2
    } | wait-job | Remove-Job -Force
}).TotalMilliseconds
#endregion