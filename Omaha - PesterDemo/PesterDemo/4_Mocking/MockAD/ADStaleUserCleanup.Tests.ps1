$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "ADStaleUserCleanup" {
    BeforeAll {
        If (Get-Module -Name ActiveDirectory) {
            Remove-Module ActiveDirectory -ErrorAction SilentlyContinue -Verbose
        }
        New-Module -Name ActiveDirectory -ScriptBlock {
            Function Get-ADUser {$Identity}
            Function Set-ADUser {Param ($Identity,$Description)}
            Function Disable-ADUser {$Identity}
            Export-ModuleMember -Function *
        } | Import-Module -Verbose       
    }
    AfterAll {
        Remove-Module ActiveDirectory -ErrorAction SilentlyContinue -Verbose
    }
    Mock -CommandName Get-ADUser -MockWith {
        return [pscustomobject]@{
            Username = 'proxb'
            LastLoginTime = (Get-Date).AddDays(-45)
            Enabled = $True
            Description = 'Some account'
        }
    }
    Context 'Get-ADUser test' {
        Mock -CommandName Get-ADUser -MockWith {
            return [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-22)
                Enabled = $True
                Description = 'Some account'
            }
        }
        It 'Should get an account' {
            (Get-ADUser -Identity 'proxb').Username | Should Be 'proxb'
        }
    }
    Context 'Set-ADUser test' {     
        Mock -CommandName Set-ADUser -MockWith {
            [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-22)
                Enabled = $True
                Description = 'Account Disabled'
            }        
        }       
        It 'Should set an account description' {
            $User = (Get-ADUser -Identity 'proxb')
            ($User | Set-ADUser -Description 'Account Disabled' -Passthru).Description | Should Be 'Account Disabled'
        }
    }
    Context 'Disable-ADUser test' {   
        Mock -CommandName Disable-ADUser -MockWith {
            return [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-22)
                Enabled = $False
                Description = 'Some account'
            }
        }         
        It 'Should disable an account' {
            $User = (Get-ADUser -Identity 'proxb')
            $User.username | Should Be 'proxb'
            ($User | Disable-ADUser -Passthru).Enabled | Should Be $False
        }
    }
    Context 'Testing the ADStaleUserCleanup function with stale account' {
        Mock -CommandName Disable-ADUser -MockWith {}
        Mock -CommandName Set-ADUser -MockWith {
            [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-45)
                Enabled = $False
                Description = 'Account Disabled'
            }        
        } -ParameterFilter {$Identity -eq 'proxb' -AND $Description -eq 'Account Disabled'}
        It 'Should perform cleanup of a user account' {
            $Result = ADStaleUserCleanup -Username proxb -DisableAfter 30
            Assert-MockCalled -CommandName Get-ADUser -Times 1
            Assert-MockCalled -CommandName Disable-ADUser -Times 1
            Assert-MockCalled -CommandName Set-ADUser -Times 1 -ParameterFilter {$Identity -eq 'proxb' -AND $Description -eq 'Account Disabled'}
            $Result.Enabled | Should Be $False
            $Result.Description | Should Be 'Account Disabled' 
        }
    }
    Context 'Testing the ADStaleUserCleanup function with current account' {
        Mock -CommandName Get-ADUser -MockWith {
            return [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-5)
                Enabled = $True
                Description = 'Some account'
            }
        }        
        Mock -CommandName Disable-ADUser -MockWith {}
        Mock -CommandName Set-ADUser -MockWith {
            [pscustomobject]@{
                Username = 'proxb'
                LastLoginTime = (Get-Date).AddDays(-10)
                Enabled = $False
                Description = 'Account Disabled'
            }        
        } -ParameterFilter {$Identity -eq 'proxb' -AND $Description -eq 'Account Disabled'}
        It 'Should perform cleanup of a user account' {
            $Result = ADStaleUserCleanup -Username proxb -DisableAfter 30
            Assert-MockCalled -CommandName Get-ADUser -Times 1
            Assert-MockCalled -CommandName Disable-ADUser -Times 0
            Assert-MockCalled -CommandName Set-ADUser -Times 0 -ParameterFilter {$Identity -eq 'proxb' -AND $Description -eq 'Account Disabled'}
            $Result | Should BeNullOrEmpty
        }
    }
}
