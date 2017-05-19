#region Lock Object against files
#region Initial File Creation
$File = 'C:\users\proxb\desktop\test.log'
'1,2,3,4' | Out-File $File
#endregion Initial File Creation

#region Take lock and attempt to update file in runspace
$LockTaken = $null
[System.Threading.Monitor]::TryEnter($File, [ref]$LockTaken)
If ($LockTaken) {
    [powershell]::Create().AddScript({
        Param($File,$RSHost)
        $LockTaken = $Null
        [System.Threading.Monitor]::TryEnter($File,1000,[ref]$LockTaken)
        If ($LockTaken) {
            '5,6,7,8' | Out-File $File -Append
        } Else {
            $RSHost.ui.WriteWarningLine("[RUNSPACE1] Unable to take lock and update file!")        
        }
    }).AddArgument($File).AddArgument($Host).Invoke()
    [System.Threading.Monitor]::Exit($File)
}
#endregion Take lock and attempt to update file in runspace

#region Take lock in Runspace and update file
[powershell]::Create().AddScript({
    Param($File,$RSHost)
    $LockTaken = $Null
    [System.Threading.Monitor]::TryEnter($File,[ref]$LockTaken)
    If ($LockTaken) {
        '9,10,11,12' | Out-File $File -Append
    } Else {
        $RSHost.ui.WriteWarningLine("[RUNSPACE2] Unable to take lock and update file!")
    }
}).AddArgument($File).AddArgument($Host).Invoke()

$LockTaken = $null
[System.Threading.Monitor]::TryEnter($File,1000,[ref]$LockTaken)
If ($LockTaken) {
    '13,14,15,16' | Out-File $File -Append
} Else {
    Write-Warning "[HOST] Unable to take lock and update file!"
}
#endregion Take lock in Runspace and update file
#endregion Lock Object against files