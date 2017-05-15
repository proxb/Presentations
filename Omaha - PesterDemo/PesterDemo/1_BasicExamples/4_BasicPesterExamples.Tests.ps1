Function Assert-OddOrEven {
    Param (
        [parameter(ValueFromPipeline)]
        $Number
    )
    Process {
        Switch ((1 -BAND $Number)) {
            0 {'Even'}
            1 {'Odd'}
        }
    }
}
#region Using It/Should with test cases
<#
    Must use Describe with It, otherwise throws error.
    Orgainzed under Describe/Context and allows a variety of methods to test.
#>
Describe 'Odd or Even Tests' {
    Context 'Odd' {
        $TestCase = @(
            @{Number = 2; ExpectedResult = 'Odd'}
            @{Number = 3; ExpectedResult = 'Odd'}
        )
        It 'Shows number is Odd' -TestCases $TestCase {
            Param ($Number, $ExpectedResult)
            Assert-OddOrEven -Number $Number | Should Be $ExpectedResult
        }
    }
    Context 'Even' {
        $TestCase = @(
            @{Number = 0; ExpectedResult = 'Even'}
            @{Number = 5; ExpectedResult = 'Even'}
        )   
        It 'Shows number is Odd' -TestCases $TestCase {
            Param ($Number, $ExpectedResult)
            Assert-OddOrEven -Number $Number | Should Be $ExpectedResult
        }         
    }
    Context 'Testing custom failure' {
        It 'Should fail nicely' {
            Throw 'this failed nicely'
        }
    }
}

## Note that strings look at each character to determine if match
#endregion Show using It/Should with various options
