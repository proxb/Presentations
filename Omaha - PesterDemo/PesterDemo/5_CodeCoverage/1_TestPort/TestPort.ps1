function Test-Port{ 
    <#   
    .SYNOPSIS   
        Tests port/s on one or more systems. 

    .DESCRIPTION 
        Tests port/s on one or more systems. 

    .PARAMETER Computername 
        Name of server to test the port connection on. 

    .PARAMETER Port 
        Port to test  
         
    .PARAMETER Protocol 
        Specific protocol to test port against.
        
        Acceptable values:
        
        TCP (Default)
        UDP                 

    .PARAMETER UDPTimeOut
        Sets a timeout for UDP port query. (In milliseconds, Default is 1000)   

    .PARAMETER TCPTimeOut
        Sets a timeout for TCP port query. (In milliseconds, Default is 1000)     
               
    .NOTES   
        Name: Test-Port.ps1 
        Author: Boe Prox 
        Version History:
            1.2 //Boe Prox | 11 Sept 2015
                - Code refactoring
            1.0 //Boe Prox | 18 Aug 2010 
                - Initial build

        List of Well-Known Ports: http://www.iana.org/assignments/port-numbers 
     
        To Do: 
            Add capability to run background jobs for each host to shorten the time to scan.   
                 
    .LINK   
        https://learn-powershell.net 

    .EXAMPLE   
        Test-Port -Computername 'server' -port 80 
        Checks port 80 on server 'server' to see if it is listening 

    .EXAMPLE   
        'server' | Test-Port -port 80 
        Checks port 80 on server 'server' to see if it is listening  

    .EXAMPLE   
        Test-Port -Computername @("server1","server2") -port 80 
        Checks port 80 on server1 and server2 to see if it is listening  
          
    .EXAMPLE   
        @("server1","server2") | Test-Port -port 80 
        Checks port 80 on server1 and server2 to see if it is listening   

    .EXAMPLE   
        (Get-Content hosts.txt) | Test-Port -port 80 
        Checks port 80 on servers in host file to see if it is listening 

    .EXAMPLE   
        Test-Port -Computername (Get-Content hosts.txt) -port 80 
        Checks port 80 on servers in host file to see if it is listening   
         
    .EXAMPLE   
        Test-Port -Computername (Get-Content hosts.txt) -port @(1..59) 
        Checks a range of ports from 1-59 on all servers in the hosts.txt file     
           
    #> 
    [cmdletbinding()] 
    Param( 
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)] 
        [Alias('CN','Computer')]
        [string[]]$Computername, 

        [Parameter(Mandatory = $True)] 
        [int[]]$Port, 

        [Parameter()] 
        [int]$TCPtimeout = 1000, 

        [Parameter()] 
        [int]$UDPtimeout = 1000,

        [parameter()]
        [int]$Throttle = 5,   
                 
        [Parameter()]
        [ValidateSet('TCP','UDP')] 
        [string[]]$Protocol = 'TCP'         
    ) 
    Begin { 
        If (!$tcp -AND !$udp) {$tcp = $True} 
        #Typically you never do this, but in this case I felt it was for the benefit of the function 
        #as any errors will be noted in the output of the report         
        $ErrorActionPreference = "SilentlyContinue" 
        $report = @() 
        } 
    Process {    
        ForEach ($computer in $Computername) { 
            ForEach ($__port in $port) { 
                If ($Protocol -eq 'TCP') {   
                    #Create temporary holder  
                    $temp = "" | Select Server, Port, TypePort, Open, Notes 
                    #Create object for connecting to port on computer 
                    $tcpobject = new-Object system.Net.Sockets.TcpClient 
                    #Connect to remote machine's port               
                    $connect = $tcpobject.BeginConnect($computer,$__port,$null,$null) 
                    #Configure a timeout before quitting 
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false) 
                    #If timeout 
                    If(!$wait) { 
                        #Close connection 
                        $tcpobject.Close() 
                        Write-Verbose "Connection Timeout" 
                        #Build report 
                        $temp.Server = $computer 
                        $temp.Port = $__port 
                        $temp.TypePort = "TCP" 
                        $temp.Open = $False 
                        $temp.Notes = "Connection to Port Timed Out" 
                        } 
                    Else { 
                        $error.Clear() 
                        $tcpobject.EndConnect($connect) | out-Null 
                        #If error 
                        If($error[0]){ 
                            #Begin making error more readable in report 
                            [string]$string = ($error[0].exception).message 
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart() 
                            $failed = $true 
                            } 
                        #Close connection     
                        $tcpobject.Close() 
                        #If unable to query port to due failure 
                        If($failed){ 
                            #Build report 
                            $temp.Server = $computer 
                            $temp.Port = $__port 
                            $temp.TypePort = "TCP" 
                            $temp.Open = $False 
                            $temp.Notes = "$message" 
                            } 
                        #Successfully queried port     
                        Else{ 
                            #Build report 
                            $temp.Server = $computer 
                            $temp.Port = $__port 
                            $temp.TypePort = "TCP" 
                            $temp.Open = $True   
                            $temp.Notes = "" 
                            } 
                        }    
                    #Reset failed value 
                    $failed = $Null     
                    #Merge temp array with report             
                    $report += $temp 
                    }     
                If ($Protocol -eq 'UDP') { 
                    #Create temporary holder  
                    $temp = "" | Select Server, Port, TypePort, Open, Notes                                    
                    #Create object for connecting to port on computer 
                    $udpobject = new-Object system.Net.Sockets.Udpclient($p) 
                    #Set a timeout on receiving message
                    $udpobject.client.ReceiveTimeout = $UDPTimeout
                    #Connect to remote machine's port               
                    Write-Verbose "Making UDP connection to remote server"
                    $udpobject.Connect("$c",$p)
                    #Sends a message to the host to which you have connected.
                    Write-Verbose "Sending message to remote host"
                    $a = new-object system.text.asciiencoding
                    $byte = $a.GetBytes("$(Get-Date)")
                    [void]$udpobject.Send($byte,$byte.length)
                    #IPEndPoint object will allow us to read datagrams sent from any source. 
                    Write-Verbose "Creating remote endpoint"
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0)
                    
                    Try {
                        #Blocks until a message returns on this socket from a remote host.
                        Write-Verbose "Waiting for message return"
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint)
                        [string]$returndata = $a.GetString($receivebytes)
                        }

                    Catch {
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") {
                            #Close connection 
                            $udpobject.Close() 
                            #Make sure that the host is online and not a false positive that it is open
                            If (Test-Connection -comp $computer -count 1 -quiet) {
                                Write-Verbose "Connection Open" 
                                #Build report 
                                $temp.Server = $computer 
                                $temp.Port = $__port 
                                $temp.TypePort = "UDP" 
                                $temp.Open = $True 
                                $temp.Notes = ""
                                }
                            Else {
                                <#
                                It is possible that the host is not online or that the host is online, 
                                but ICMP is blocked by a firewall and this port is actually open.
                                #>
                                Write-Verbose "Host maybe unavailable" 
                                #Build report 
                                $temp.Server = $computer 
                                $temp.Port = $__port 
                                $temp.TypePort = "UDP" 
                                $temp.Open = $False 
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."                                
                                }                        
                            }
                        ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) {
                            #Close connection 
                            $udpobject.Close() 
                            Write-Verbose "Connection Timeout" 
                            #Build report 
                            $temp.Server = $computer 
                            $temp.Port = $__port 
                            $temp.TypePort = "UDP" 
                            $temp.Open = $False 
                            $temp.Notes = "Connection to Port Timed Out"                        
                            }
                        Else {                        
                            $udpobject.close()
                            Write-Verbose "Something else happened" 
                            #Build report 
                            $temp.Server = $computer 
                            $temp.Port = $__port 
                            $temp.TypePort = "UDP" 
                            $temp.Open = $False 
                            $temp.Notes = "Connection Unavailable"                            
                            }
                        }    
                    #Merge temp array with report             
                    $report += $temp 
                    }                                 
                } 
            }                 
        } 
    End { 
        #Generate Report 
        $report 
        }         
}
