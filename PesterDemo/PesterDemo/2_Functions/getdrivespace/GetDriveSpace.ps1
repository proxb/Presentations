function Get-DriveSpace {
    Param (
        ## Remove to show ValueFromPipeline
        [parameter(ValueFromPipeline)]
        [string]$Computername
    )
    Begin {
        $WMIParams = @{
            Filter = "DriveType='3' AND (Not Name LIKE '\\\\?\\%')" 
            Class = "Win32_Volume"
            ErrorAction = "Stop"
            Property = "Name","Label","Capacity","FreeSpace"
        }
    }
    Process {  
        ## Remove comment to show test-connection
        If ((Test-Connection -ComputerName $Computername -Count 1 -Quiet)) {          
            $WMIParams.Computername = $Computername
            Get-WmiObject @WMIParams | ForEach {
                [pscustomobject]@{
                    Computername = $Computername
                    Name = $_.Name
                    Label = $_.Label
                    CapacityGB = ("{0:N2}" -f ($_.Capacity /1GB))
                    FreeSpaceGB = ("{0:N2}" -f ($_.FreeSpace /1GB))
                    PercentFree = ("{0:P}" -f ($_.FreeSpace / $_.Capacity))
                }
            }
        } Else {Throw "$Computername not available!"}
    }
}
