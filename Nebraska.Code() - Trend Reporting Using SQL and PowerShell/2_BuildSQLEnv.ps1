#region Helper Functions
# I could use a different function for Testing and Creating of Database and Table, but it is more efficient
# to use a single function here.
# http://poshcode.org/5695 has a much nicer version (Invoke-SQLCmd2) with tons more functionality!
Function Invoke-SQLCmd {   
    [cmdletbinding(
        DefaultParameterSetName = 'NoCred',
        SupportsShouldProcess = $True,
        ConfirmImpact = 'Low'
    )]
    Param (
        [parameter()]
        [string]$Computername = 'boe-pc',
       
        [parameter()]
        [string]$Database = 'Master',   
        
        [parameter()]
        [string]$TSQL,
 
        [parameter()]
        [int]$ConnectionTimeout = 30,
 
        [parameter()]
        [int]$QueryTimeout = 120,
 
        [parameter()]
        [System.Collections.ICollection]$SQLParameter,
 
        [parameter(ParameterSetName='Cred')]
        [Alias('RunAs')]       
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
 
        [parameter()]
        [ValidateSet('Query','NonQuery')]
        [string]$CommandType = 'Query'
    )
    If ($PSBoundParameters.ContainsKey('Debug')) {
        $DebugPreference = 'Continue'
    }
    $PSBoundParameters.GetEnumerator() | ForEach {
        Write-Debug $_
    }
    #region Make Connection
    Write-Verbose "Building connection string"
    $Connection=new-object System.Data.SqlClient.SQLConnection
    Switch ($PSCmdlet.ParameterSetName) {
        'Cred' {
            $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $Computername,
                                                                                        $Database,$Credential.Username,
                                                                                        $Credential.GetNetworkCredential().password,$ConnectionTimeout  
            Remove-Variable Credential
        }
        'NoCred' {
            $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $Computername,$Database,$ConnectionTimeout                
        }
    }  
    $Connection.ConnectionString=$ConnectionString
    Write-Verbose "Opening connection to $($Computername)"
    $Connection.Open()
    #endregion Make Connection
 
    #region Initiate Query
    Write-Verbose "Initiating query"
    $Command=new-object system.Data.SqlClient.SqlCommand($Tsql,$Connection)
    If ($PSBoundParameters.ContainsKey('SQLParameter')) {
        $SqlParameter.GetEnumerator() | ForEach {
            Write-Debug "Adding SQL Parameter: $($_.Key) with Value: $($_.Value) <$($_.Value.GetType().Fullname)>"
            If ($_.Value -ne $null) {
                [void]$Command.Parameters.AddWithValue($_.Key, $_.Value)
            }
            Else {
                [void]$Command.Parameters.AddWithValue($_.Key, [DBNull]::Value)
            }
        }
    }
    $Command.CommandTimeout=$QueryTimeout
    If ($PSCmdlet.ShouldProcess("Computername: $($Computername) - Database: $($Database)",'Run TSQL operation')) {
        Switch ($CommandType) {
            'Query' {
                Write-Verbose "Performing Query operation"
                $DataSet=New-Object system.Data.DataSet
                $DataAdapter=New-Object system.Data.SqlClient.SqlDataAdapter($Command)
                [void]$DataAdapter.fill($DataSet)
                $DataSet.Tables
            }
            'NonQuery' {
                Write-Verbose "Performing Non-Query operation"
                [void]$Command.ExecuteNonQuery()
            }
        }
    }
    #endregion Initiate Query   
 
    #region Close connection
    Write-Verbose "Closing connection"
    $Connection.Close()       
    #endregion Close connection
}
#endregion Helper Functions

#region Check/Create for database
$Database = 'Drive_Space1'
$SQLParams = @{
    Computername = 'boe-pc'
    Database = 'Master'
    CommandType = 'Query'
    ErrorAction = 'Stop'
    SQLParameter = @{
        '@DatabaseName' = $Database
    }
    Verbose = $True
    Debug = $True
    Confirm=$False
}
$SQLParams.TSQL = "SELECT Name FROM sys.databases WHERE Name = @DatabaseName"
$Results = Invoke-SQLCmd @SQLParams
If ($Results.Name -eq $Null) {
    #Proceed with building the database and Table
    $SQLParams.CommandType='NonQuery'
    $SQLParams.Remove('SQLParameter')
    $SQLParams.TSQL = "CREATE Database $Database"
    Invoke-SQLCmd @SQLParams
} 

#Verify Database exists now
$SQLParams.TSQL = "SELECT Name FROM sys.databases WHERE Name = @DatabaseName"
$SQLParams.    SQLParameter = @{
    '@DatabaseName' = $Database
}
$SQLParams.CommandType = 'Query'
Invoke-SQLCmd @SQLParams
#endregion Check/Create for database

#region Check/Create Table
#Now test for the table
$Table = 'tbDriveSpace'
$SQLParams.CommandType = 'Query'
$SQLParams.SQLParameter = @{
    '@TableName' = $Table
}
$SQLParams.Database = 'Drive_Space1'    
$SQLParams.TSQL = "SELECT TABLE_NAME AS Name FROM information_schema.tables WHERE TABLE_NAME = @TableName"
$Results = Invoke-SQLCmd @SQLParams
If ($Results.Name -eq $Null) {
    #Create the table
    $SQLParams.Remove('SQLParameter')
    $SQLParams.CommandType='NonQuery'
    $SQLParams.TSQL = "CREATE TABLE $Table  (
        DateStamp datetime,
        ComputerName varchar (50), 
        DeviceID varchar (50), 
        VolumeName  varchar (50),
        Size bigint ,
        FreeSpace bigint, 
        UsedSpace bigint
    )"
    Invoke-SQLCmd @SQLParams
}

#Verify Table exists now
$SQLParams.TSQL = "SELECT TABLE_NAME AS Name FROM information_schema.tables WHERE TABLE_NAME = @TableName"
$SQLParams.SQLParameter = @{
    '@TableName' = $Table
}
$SQLParams.CommandType = 'Query'
Invoke-SQLCmd @SQLParams
#endregion Check/Create Table