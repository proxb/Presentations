#region Using It with various options
<#

    Must use Describe with It, otherwise throws error.
    Orgainzed under Describe/Context and allows a variety of methods to test.
#>
Describe 'Boolean Tests' {
    Context '$True tests' {
        It 'Should be $True' {
            $True | Should Be $True
        }
        It 'Should be $True' {
            $False | Should Be $True
        }
    }
    Context '$False tests' {
        It 'Should be $False' {
            $False | Should Be $False
        }
        It 'Should be $True' {
            $True | Should Be $False
        }
    }
}
#endregion Show using It with various options
