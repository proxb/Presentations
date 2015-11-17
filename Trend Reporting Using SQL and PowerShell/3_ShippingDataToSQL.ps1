#region Ensure that we have our helper functions in place
Function Get-DriveSpace {
    [cmdletbinding()]
    Param (
        [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string[]]$Computername,

        [parameter(ParameterSetName='Cred')]
        [Alias('RunAs')]        
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    Begin {
        If ($PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference='Continue'
        }
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Debug $_
        }
        $Date = $Date = (Get-Date).ToString()
        $WMIParams = @{
          Class =  'Win32_Volume' 
          ErrorAction =  'Stop' 
          Filter=  "DriveType='3' AND (Not Name LIKE '\\\\?\\%')"  
          Property =  'DriveLetter','Label','Capacity','FreeSpace','DriveLetter'
        } 
        If ($PSBoundParameters.ContainsKey('Credential')) {
            $WMIParams.Credential=$Credential
        }
    }
    Process {
        ForEach ($Computer in $Computername) {
            $WMIParams.Computername = $Computer
            Try {
                Write-Verbose "$($Computer): Retrieving disk information"
                Get-WmiObject @WMIParams | ForEach {
                    [pscustomobject]@{
                        Computername = $Computer
                        DateStamp = $Date
                        Size = [int64]$_.Capacity
                        FreeSpace = [int64]$_.Freespace
                        UsedSpace = [int64]($_.Capacity - $_.Freespace)
                        DeviceID = $_.DriveLetter
                        VolumeName = $_.Label
                    }
                }
            }
            Catch {
                Throw "$($Computer): $_"
            }
            Finally {
                $WMIParams.Remove('Computername')
            }
        }
    }
}
Function Get-Server {
    [cmdletbinding(DefaultParameterSetName='All')]
    Param (
        [parameter(ParameterSetName='DomainController')]
        [switch]$DomainController,
        [parameter(ParameterSetName='MemberServer')]
        [switch]$MemberServer
    )
    Write-Verbose "Parameter Set: $($PSCmdlet.ParameterSetName)"
    Switch ($PSCmdlet.ParameterSetName) {
        'All' {
            $ldapFilter = "(&(objectCategory=computer)(OperatingSystem=Windows*Server*))"
        }
        'DomainController' {
            $ldapFilter = "(&(objectCategory=computer)(OperatingSystem=Windows*Server*)(userAccountControl:1.2.840.113556.1.4.803:=8192))"
        }
        'MemberServer' {
            $ldapFilter = "(&(objectCategory=computer)(OperatingSystem=Windows*Server*)(!(userAccountControl:1.2.840.113556.1.4.803:=8192)))"
        }
    }
    $searcher = [adsisearcher]""
    $Searcher.Filter = $ldapFilter
    $Searcher.pagesize = 10
    $searcher.sizelimit = 5000
    $searcher.PropertiesToLoad.Add("name") | Out-Null
    $Searcher.sort.propertyname='name'
    $searcher.Sort.Direction = 'Ascending'
    $Searcher.FindAll() | ForEach {
        $_.Properties.name
    }
}
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
#endregion Ensure that we have our helper functions in place

# I'm not worried about multiple open/closes with Invoke-SqlCmd due to .Net connection pooling.
$SQLParams = @{
    Computername = 'boe-pc'
    Database = 'Drive_Space1'
    CommandType = 'NonQuery'
    ErrorAction = 'Stop'
    Verbose = $True
    Debug = $True
    Confirm=$False
}

#region System Collections
Write-Verbose "Gathering list of systems" -Verbose
# $Computername = Get-Server | Sort
[string[]]$Computername = $env:COMPUTERNAME
#endregion System Collections

#region Ship disk space data to SQL
ForEach ($Computer in $Computername) {
    Try {
        $Disks = Get-DriveSpace -Computername $Computer
        ForEach ($Disk in $Disks) {
            #Need to cast this value from UInt64 to Int64, otherwise it will throw an error
            $SQLParams.SQLParameter = @{
                '@DateStamp' = $Disk.DateStamp
                '@Computername' = $Disk.Computername
                '@DeviceID' = $Disk.DeviceID
                '@VolumeName' = $Disk.VolumeName
                '@Size' = $Disk.Size
                '@FreeSpace' = $Disk.FreeSpace
                '@UsedSpace' = $Disk.UsedSpace
            }
            $SQLParams.TSQL  = "INSERT  INTO [tbDRIVESPACE] (DateStamp, Computername, DeviceID, VolumeName, Size,  FreeSpace, UsedSpace) `            
            VALUES (@DateStamp, @Computername, @DeviceID, @VolumeName, @Size, @FreeSpace, @UsedSpace)"
            Try {
                Invoke-SQLCmd @SQLParams
            } Catch {
                Write-Warning $_
            }
        }
    } Catch {
        Write-Warning "$($Computer): $_"
    }
}
#endregion Ship disk space data to SQL