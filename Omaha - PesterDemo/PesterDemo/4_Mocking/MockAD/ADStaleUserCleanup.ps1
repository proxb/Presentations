function ADStaleUserCleanup {
    Param (
        [Parameter(ValueFromPipeline)]
        [string[]]$Username, 
        [int]$DisableAfter
    )
    Process {
        $UserAccount = Get-ADUser -Identity $Username
        If ($UserAccount.lastlogintime -lt (Get-Date).AddDays(-$DisableAfter)) {
            $UserAccount | Disable-ADUser 
            Set-ADUser -Identity $UserAccount.Username -Description "Account Disabled"
        }
    }
}
