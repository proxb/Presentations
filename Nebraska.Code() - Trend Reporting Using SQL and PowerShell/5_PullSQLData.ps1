#region Helper Functions
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

$SQLParams = @{
    Computername = 'boe-pc'
    Database = 'Drive_Space'
    CommandType = 'Query'
    ErrorAction = 'Stop'
    SQLParam = @{
        '@Computername' = 'boe-pc'
        '@StartDate' = (Get-Date).AddDays(-180).ToString()
        '@EndDate' = (Get-Date).ToString()
    }
    Verbose = $True
    Debug = $True
    Confirm=$False
}

#region SQL query for space
$SQLParams.TSQL = "SELECT * FROM [tbDRIVESPACE] WHERE  (Computername = @Computername) AND (DateStamp > @StartDate AND DateStamp < @EndDate)"
$Data = Invoke-SQLCmd @SQLParams
#endregion SQL query for space

$Data

#Note that the return object is System.Data.DataTable
$Data.GetType().Fullname

# Data converted to GB
# I only need the following properties: VolumeName, DateStamp, UsedSpaceGB and CapacityGB -- In this order!!
# I could use Add-Member here, but it is a slower process
# Common example is if you have multiple drives using DFSShares
$UpdatedData = ForEach ($Item in $Data[0].Rows) {
    [pscustomobject]@{
        VolumeName = $Item.VolumeName
        DateStamp = $Item.DateStamp
        UsedSpace =  ([math]::Round((($Item.Size /1GB) - ($Item.FreeSpace /1GB)),2))
        CapacityGB = [math]::Round(($Item.Size /1GB),2)        
    }
}

# Data can now be sent to a CSV for further use; use a meaningful name for report
# I want to make sure that I create a file for each drive on each system
# If I only queried for a specific drive, then this can be adjusted
$UpdatedData | Group VolumeName | ForEach {
    $_.Group | Sort DateStamp | Export-Csv -NoTypeInformation -Path "$($_.Name).csv" -Verbose
}

# If you do not deal with VolumeNames, this can be adjusted for Drive Letter
$UpdatedData = ForEach ($Item in $Data) {
    [pscustomobject]@{
        DeviceID = $Item.DeviceID
        DateStamp = $Item.DateStamp
        UsedSpaceGB =  ([math]::Round((($Item.Size /1GB) - ($Item.FreeSpace /1GB)),2))
        CapacityGB = [math]::Round(($Item.Size /1GB),2)        
    }
}

$UpdatedData | Group DeviceID | ForEach {
    $_.Group | Sort DateStamp | Export-Csv -NoTypeInformation -Path "$($_.Name.SubString(0,1)).csv" -Verbose
}

## Or we can merge to show both
$UpdatedData = ForEach ($Item in $Data[0].Rows) {
    [pscustomobject]@{
        Name = "$($Item.DeviceID.SubString(0,1)) ($($Item.VolumeName))"
        DateStamp = $Item.DateStamp
        UsedSpaceGB =  ([math]::Round((($Item.Size /1GB) - ($Item.FreeSpace /1GB)),2))
        CapacityGB = [math]::Round(($Item.Size /1GB),2)        
    }
}

$UpdatedData | Group Name | ForEach {
    $_.Group | Sort DateStamp | Export-Csv -NoTypeInformation -Path "$($_.Name).csv" -Verbose
}