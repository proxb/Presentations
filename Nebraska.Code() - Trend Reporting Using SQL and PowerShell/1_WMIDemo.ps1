#region Determine approach to pulling data
#Better to filter as far left as possible and use parameters where available
Get-WMIObject -Query "Select * FROM Win32_Volume WHERE DriveType=3" | Where {
    Write-Verbose $_ -Verbose
} | Out-Null

Get-WMIObject -Class Win32_Volume | Where {
    Write-Verbose $_ -Verbose
    $_.DriveType -eq 3
} | Out-Null

Get-WMIObject -Class Win32_Volume -Filter "DriveType='3'"
#endregion Determine approach to pulling data

#region Splatting Variables
#Useful for organizing parameter data and to update existing parameters
$WMIParams = @{
  Class =  'Win32_Volume' 
  ErrorAction =  'Stop' 
  Filter=  "DriveType='3' AND (Not Name LIKE '\\\\?\\%')"  
  Property =  'DriveLetter','Label','Capacity','FreeSpace'
} 
Get-WMIObject @WMIParams
#endregion Splatting Variables

#region CIM Example
#Same common parameters as Get-WMIObject, but uses WS-MAN vs. DCOM by default (unless you connect to local system)
Get-CimInstance @WMIParams
#endregion CIM Example

#region Pull all servers
#Use a custom function if AD Module not available
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

$Computername = Get-Server

#If AD Module available
Get-ADComputer -Filter {operatingsystem -like '*server*'} | Select -ExpandProperty Name
#endregion Pull all servers

#region Put it all together
$WMIParams = @{
  Class =  'Win32_Volume' 
  ErrorAction =  'Stop' 
  Filter=  "DriveType='3' AND (Not Name LIKE '\\\\?\\%')"  
  Property =  'DriveLetter','Label','Capacity','FreeSpace'
} 
$Computername = $env:COMPUTERNAME #If on a domain, I would use Get-Server or Get-ADComputer
ForEach ($Computer in $Computername) {
    If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
        $WMIParams.Computername = $Computer
        Try {
            Get-WMIObject @WMIParams
        } 
        Catch {
            Write-Warning "[$($Computer)]: $_"
        }
        Finally {
            #Not really needed, but showing what all we can do
            $WMIParams.Remove('Computername')
        }
    }
}
#endregion Put it all together

#region Turn this into an Advanced Function
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
#endregion Turn this into an Advanced Function

#region Running the function
Get-DriveSpace -Computername $Env:COMPUTERNAME -Verbose -Debug
#Pipeline support
$env:COMPUTERNAME | Get-DriveSpace -Verbose -Debug

#Pipeline support by property name
$Object = [pscustomobject]@{Computername=$env:COMPUTERNAME;Note='Some note'}
$Object
$Object | Get-DriveSpace -Verbose -Debug
#endregion Running the function