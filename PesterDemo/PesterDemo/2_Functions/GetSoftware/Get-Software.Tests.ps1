$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe 'Get-Software Testing' {
    Context 'Ensure that we have valid output' {
        It 'Should return data' {
            Get-Software -Computername $Env:COMPUTERNAME | Should Not BeNullOrEmpty
        }
        It 'Should accept pipeline input' {
            ($Env:COMPUTERNAME | Get-Software) | Should Not BeNullOrEmpty
        }
        It 'Should allow more than 1 system' {
            # This needs to be Mocked because we can't be sure that more than 1 system is available to test
            Mock Get-Software {
                [pscustomobject]@{Computername='Computer1'}
                [pscustomobject]@{Computername='Computer2'}
            }
            $Return = (Get-Software -Computername 'Computer1','Computer2') | Group Computername
            $Return.Count | Should Be 2
            Assert-MockCalled -CommandName Get-Software -Exactly 1
        }
        It 'Should have a Computername property' {
            (Get-Software -Computername $env:COMPUTERNAME | Get-Member -Name Computername).Name | Should Be 'Computername'
        }
    }
    Context 'Test for errors' {
        It 'Should throw an error if invalid/unavailable computername' {
            {Get-Software -Computername DoesNotExist -ErrorAction Stop} | Should Throw
        }
        It 'Should throw an error if registry access issues' {
            # Mocking Test-Connecton to force it to return $True to test failed registry connection
            Mock Test-Connection {$True}
            {Get-Software -Computername DoesNotExist -ErrorAction Stop} | Should Throw
            Assert-MockCalled -CommandName Test-Connection -Exactly 1
        }
    }
}
