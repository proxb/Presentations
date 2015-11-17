$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "TestPort" {
    Context "TCP" {
        It "Should return object" {
            Test-Port -Computername $Env:Computername -Port 135 -Protocol TCP | Should Not BeNullOrEmpty
        }
        It "Should return open port" {
            $Data = Test-Port -Computername $Env:Computername -Port 135 -Protocol TCP 
            $Data.Open | Should Be $True
        }
        It "Should return closed port" {
            $Data = Test-Port -Computername $Env:Computername -Port 13 -Protocol TCP
            $Data.Open | Should Be $False
        }
        It "Should timeout on attempt" {
            $Data = Test-Port -Computername $Env:Computername -Port 13 -Protocol TCP
            $Data.Notes | Should Match 'Connection to Port Timed Out'
        }
        It "Should have errors on attempt other than a timeout" {
            $Data = Test-Port -Computername $Env:Computername -Port 25 -Protocol TCP
            $Data.Notes -notmatch 'Timed Out' | Should Be $True
        }
    }
    Context "UDP" {
        It "Should return object" {
            Test-Port -Computername $Env:Computername -Port 135 -Protocol UDP | Should Not BeNullOrEmpty
        }
        It "Should return closed port" {
            $Data = Test-Port -Computername $Env:Computername -Port 13 -Protocol UDP
            $Data.Open | Should Be $False
        }
        It "Should timeout on attempt" {
            $Data = Test-Port -Computername $Env:Computername -Port 25 -Protocol UDP
            $Data.Notes -like '*Timed Out*' | Should Be $True
        }
        It "Should fail on an unknown host" {
            $Data = Test-Port -Computername DoesNotExist -Port 25 -Protocol UDP
            $Data.Notes -like 'Connection to Port Timed Out' | Should Be $True
        }
    }
    Context "UDP and TCP" {
        It "Should return object" {
            Test-Port -Computername $Env:Computername -Port 135 -Protocol UDP,TCP | Should Not BeNullOrEmpty
        }
        It "Should return closed port" {
            $Data = Test-Port -Computername $Env:Computername -Port 13 -Protocol UDP,TCP
            $Data[0].Open | Should Be $False
            $Data[1].Open | Should Be $False
        }
        It "Should return Open (TCP)/Filtered (UDP) port" {
            # Needs Mocked
            Mock -CommandName Test-Port -MockWith {
                [pscustomobject]@{
                    Computername = $Env:Computername 
                    Port = 25 
                    Protocol = "TCP" 
                    State = 'Open' 
                    Notes = $Null
                }
                [pscustomobject]@{
                    Computername = $Env:Computername 
                    Port = 25 
                    Protocol = "UDP" 
                    State = 'Filtered' 
                    Notes = $Null                    
                }
            }
            $Data = Test-Port -Computername $Env:Computername -Port 135 -Protocol UDP,TCP 
            $Data[0].State | Should Be 'Open'
            $Data[1].State | Should Be 'Filtered'
        }
    }
    Context "Error Testing" {
        It "Should throw an error if a non integer is used for port" {
            {Test-Port -Computername $env:COMPUTERNAME -Port 'fail' -Protocol TCP -ErrorAction Stop} | Should Throw
        }
        It "Should throw an error if an incorrect protocol is used" {
            {Test-Port -Computername $env:COMPUTERNAME -Port 25 -Protocol IPX -ErrorAction Stop} | Should Throw
        }
    }
}