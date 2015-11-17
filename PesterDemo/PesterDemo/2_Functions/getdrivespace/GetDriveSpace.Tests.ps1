$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "GetDriveSpace" {
    It "Checks Drive Space" {
        Get-DriveSpace -Computername $env:COMPUTERNAME | Should Not BeNullOrEmpty
    }
    It "Throws if Computer not available" {
        {Get-DriveSpace -Computername DoesNotExist} | Should Throw
    }
    It "Accepts value from pipeline" {
        $env:COMPUTERNAME | Get-DriveSpace | Should Not BeNullOrEmpty
    }
    It "Accepts multiple systems" {
        ($env:COMPUTERNAME,$env:COMPUTERNAME,$env:COMPUTERNAME | Get-DriveSpace).count | Should BeGreaterThan 2
    }
}
