Function Get-Software {
    [OutputType('System.Software.Inventory')]
    [Cmdletbinding()] 
    Param( 
        [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)] 
        [String[]]$Computername=$env:COMPUTERNAME
    )         
    Begin {
    }
    Process {     
        ForEach ($Computer in $Computername){ 
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                $Paths = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall","SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")         
                ForEach($Path in $Paths) { 
                    # Create an instance of the Registry Object and open the HKLM base key 
                    Try { 
                        $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$Computer) 
                    } Catch { 
                        Write-Error $_ 
                        Continue 
                    } 
                    # Drill down into the Uninstall key using the OpenSubKey Method 
                    Try {
                        $regkey=$reg.OpenSubKey($Path)  
                        # Retrieve an array of string that contain all the subkey names 
                        $subkeys=$regkey.GetSubKeyNames()      
                        # Open each Subkey and use GetValue Method to return the required values for each 
                        ForEach ($key in $subkeys){   
                            $thisKey=$Path+"\\"+$key 
                            Try {  
                                $thisSubKey=$reg.OpenSubKey($thisKey)   
                                # Prevent Objects with empty DisplayName 
                                $DisplayName = $thisSubKey.getValue("DisplayName")
                                If ($DisplayName -AND $DisplayName -notmatch '^Update for|rollup|^Security Update|^Service Pack|^HotFix') {
                                    $Date = $thisSubKey.GetValue('InstallDate')
                                    If ($Date) {
                                        $Date = [datetime]::ParseExact($Date, 'yyyyddMM', $Null)
                                    } 
                                    # Create New Object with empty Properties 
                                    $Object = [pscustomobject]@{
                                        Computername = $Computer
                                        DisplayName = $DisplayName
                                        Version = $thisSubKey.GetValue('DisplayVersion')
                                        InstallDate = $Date
                                        Publisher = $thisSubKey.GetValue('Publisher')
                                        UninstallString = $thisSubKey.GetValue('UninstallString')
                                        InstallLocation = $thisSubKey.GetValue('InstallLocation')
                                        InstallSource = $thisSubKey.GetValue('InstallSource')
                                        HelpLink = $thisSubKey.GetValue('HelpLink')
                                        EstimatedSizeMB = [math]::Round(($thisSubKey.GetValue('EstimatedSize')*1024)/1MB,2)
                                    }
                                    $Object.pstypenames.insert(0,'System.Software.Inventory')
                                    Write-Output $Object
                                }
                            } Catch {
                    
                            }   
                        }
                    } Catch {}   
                    $reg.Close() 
                }                  
            } Else {
                Write-Error "$($Computer): unable to reach remote system!"
            }
        } 
    } 
} 