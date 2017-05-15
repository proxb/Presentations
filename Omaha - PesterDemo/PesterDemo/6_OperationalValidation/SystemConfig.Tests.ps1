Function Convert-UserFlag {
    Param ($UserFlag)
    $List = New-Object System.Collections.ArrayList
    Switch ($UserFlag) {
        ($UserFlag -BOR 0x0001)  {[void]$List.Add('SCRIPT')}
        ($UserFlag -BOR 0x0002)  {[void]$List.Add('ACCOUNTDISABLE')}
        ($UserFlag -BOR 0x0008)  {[void]$List.Add('HOMEDIR_REQUIRED')}
        ($UserFlag -BOR 0x0010)  {[void]$List.Add('LOCKOUT')}
        ($UserFlag -BOR 0x0020)  {[void]$List.Add('PASSWD_NOTREQD')}
        ($UserFlag -BOR 0x0040)  {[void]$List.Add('PASSWD_CANT_CHANGE')}
        ($UserFlag -BOR 0x0080)  {[void]$List.Add('ENCRYPTED_TEXT_PWD_ALLOWED')}
        ($UserFlag -BOR 0x0100)  {[void]$List.Add('TEMP_DUPLICATE_ACCOUNT')}
        ($UserFlag -BOR 0x0200)  {[void]$List.Add('NORMAL_ACCOUNT')}
        ($UserFlag -BOR 0x0800)  {[void]$List.Add('INTERDOMAIN_TRUST_ACCOUNT')}
        ($UserFlag -BOR 0x1000)  {[void]$List.Add('WORKSTATION_TRUST_ACCOUNT')}
        ($UserFlag -BOR 0x2000)  {[void]$List.Add('SERVER_TRUST_ACCOUNT')}
        ($UserFlag -BOR 0x10000)  {[void]$List.Add('DONT_EXPIRE_PASSWORD')}
        ($UserFlag -BOR 0x20000)  {[void]$List.Add('MNS_LOGON_ACCOUNT')}
        ($UserFlag -BOR 0x40000)  {[void]$List.Add('SMARTCARD_REQUIRED')}
        ($UserFlag -BOR 0x80000)  {[void]$List.Add('TRUSTED_FOR_DELEGATION')}
        ($UserFlag -BOR 0x100000)  {[void]$List.Add('NOT_DELEGATED')}
        ($UserFlag -BOR 0x200000)  {[void]$List.Add('USE_DES_KEY_ONLY')}
        ($UserFlag -BOR 0x400000)  {[void]$List.Add('DONT_REQ_PREAUTH')}
        ($UserFlag -BOR 0x800000)  {[void]$List.Add('PASSWORD_EXPIRED')}
        ($UserFlag -BOR 0x1000000)  {[void]$List.Add('TRUSTED_TO_AUTH_FOR_DELEGATION')}
        ($UserFlag -BOR 0x04000000)  {[void]$List.Add('PARTIAL_SECRETS_ACCOUNT')}
    }
    $List -join ', '
}
Function Get-LocalUser {
    [Cmdletbinding()] 
    Param( 
        [Parameter()] 
        [String[]]$Computername = $Env:Computername
    )
    $adsi = [ADSI]"WinNT://$Computername"
    $adsi.Children | where {$_.SchemaClassName -eq 'user'} |
    Select @{L='Name';E={$_.Name[0]}}, 
    @{L='PasswordAge';E={("{0:N0} Days" -f ($_.PasswordAge[0]/86400))}}, 
    @{L='LastLogin';E={If ($_.LastLogin[0] -is [datetime]){$_.LastLogin[0]}Else{'Never logged on'}}}, 
    @{L='UserFlags';E={(Convert-UserFlag -UserFlag $_.UserFlags[0])}}
}

Describe "[$($env:COMPUTERNAME)] System Configuration Test" {
    Context 'Drive Space' {
        Get-WMIObject -Class Win32_Volume -Filter "DriveType = '3'" | ForEach {
            It "$($_.Name) drive should have enough free space" {
                ($_.FreeSpace / 1GB) | Should BeGreaterThan 10
                ($_.FreeSpace / $_.Capacity) | Should BeGreaterThan .10
            }
        }
    }
    Context 'Service Checks' {
        $Services = @(Get-WmiObject -Class Win32_Service -Filter "State != 'running' AND StartMode = 'Auto'")
        If ($Services.count -gt 0) {                
            $Services | ForEach {
                It "$($_.DisplayName) should be running" {
                    $_.State | Should Be 'Running'
                }
            }
        } Else {
            It 'Should have no services stopped that are set to Automatic' {
                $Services.Count | Should Be 0
            }
        }
    }
    Context 'Internet Access' {
        It 'Should access Google' {
            (New-Object Net.Sockets.TCPClient -ArgumentList 'google.com',80).Available | Should Be 0
        }
    }
    Context 'Security Settings' {
        It 'Should have SSLV3 Disabled' { 
            $KeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client'          
            (Get-ItemProperty -Name DisabledByDefault -path $KeyPath -ErrorAction SilentlyContinue).DisabledByDefault | Should Be 1
        }
        It 'Should have FIPS Enabled' {
            $KeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy'
            (Get-ItemProperty -Name Enabled -Path $KeyPath).Enabled | Should Be 1
        }
    }
    Context 'Accounts' {
        BeforeAll {
            $LocalAccounts = Get-LocalUser
            $DisabledAccounts = @($LocalAccounts | Where {$_.UserFlags -match 'ACCOUNTDISABLE'})
            $ExpiredPasswords = @($LocalAccounts | Where {$_.UserFlags -match 'PASSWORD_EXPIRED'})
            $StaleUser = @($LocalAccounts | Where {$_.LastLogin -lt (Get-Date).AddDays(-30)})
        }

        If ($DisabledAccounts.count -gt 0) {
            $DisabledAccounts | ForEach {
                It "$($_.Name) Should not be Disabled" {
                    $_.UserFlags | Should Not Match 'ACCOUNTDISABLE'
                }
            }
        } Else {
            It 'Has no accounts that are disabled' {
                $DisabledAccounts.Count | Should Be 0
            }       
        }

        If ($ExpiredPasswords.count -gt 0) {
            $ExpiredPasswords | ForEach {
                It "$($_.Name) Should not have expired passwords" {
                    $_.UserFlags | Should Not Match 'PASSWORD_EXPIRED'
                }
            }
        } Else {
            It 'Has accounts with no expired passwords' {
                $ExpiredPasswords.Count | Should Be 0
            }       
        }

        If ($StaleUser.count -gt 0) {
            $StaleUser | ForEach {
                It "$($_.Name) Should not be a stale account (not logged in over 30 days)" {
                    ((get-Date) - $_.LastLogin).Days | Should BeLessThan 30
                }
            }
        } Else {
            It 'Has accounts that have not been logged in for at least 30 days' {
                $StaleUser.Count | Should Be 0
            }       
        }
    }
}