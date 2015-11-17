#region More Should Examples
Describe 'Lots of Should operation Examples' {
    #Example of one failed causes entire test to fail
    It '"Should Be" Example which will fail' {
        1 | Should Be 1
        2 | Should Be 1
    }

    It '"Should Be" Example' {
        1 | Should Be 1
    }

    It '"Should Not Be" Example' {
        1 | Should Not Be 2
    }

    It '"Should BeNullOrEmpty" Example' {
        @() | Should BeNullOrEmpty
        '' | Should BeNullOrEmpty
    }

    It '"Should Match" Example' {
        'test' | Should Match 'te'
    }

    It '"Should Not Match" Example' {
        'te' | Should Not Match 'test'
    }

    It '"Should Not MatchExactly" Example' {
        'tex' | Should Not MatchExactly 'test'
    }

    #Testing existence of a path
    It '"Should Exist" Example' {
        'C:\Windows' | Should Exist
    }    

    Context 'Testing TestDrive:\ being written to' {
        #You can use a created TestDrive to generate/test log files
        It '"Should Contain" Data Example' {
            $File = 'TestDrive:\test.txt'
            'I am some example' | Out-File $File
            $File | Should Exist
            $File | Should Contain example            
        }
    }

    Context 'Show TestDrive' {
        Get-PSDrive -Name TestDrive|format-list | Out-Host
    }

    It '"Should Throw" Example' {
        #Must use script block for this
        {1/0} | Should Throw
    }

    It '"Should not Throw" Example' {
        #Must use script block for this
        {1+1} | Should Not Throw
    }

    #Cannot just test a type using Should; have to use -IS and evaluate that it is $True
    It 'Should test 1 type as Int' {
        (1 -is [int]) | Should Be $True
    }
    It 'Should test output from Get-Date type as DateTime' {
        ((Get-Date) -is [DateTime]) | Should Be $True
    }
    It '"Should work" with objects' {
        $Object = @([pscustomobject]@{
            test = 1
            Date = (Get-Date)
        })
        $Object.Count | Should Be 1
        $Object.Date.GetType().Name | Should Be 'DateTime'
    }
}
#endregion More Should Examples