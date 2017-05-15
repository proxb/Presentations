Function Test-Port {
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
        Function TestTCPPort {
            Param ($Computername,$Port,$TCPtimeout)
            #Create object for connecting to port on computer 
            $tcpobject = New-Object Net.Sockets.TcpClient 

            #Connect to remote machine's port               
            $connect = $tcpobject.BeginConnect($Computername,$Port,$null,$null) 

            #Configure a timeout before quitting 
            $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false) 

            #If timeout 
            If(-NOT $wait) { 
                Write-Verbose "Connection Timeout" 
                [pscustomobject]@{
                    Computername = $Computername 
                    Port = $Port 
                    Protocol = "TCP" 
                    State = 'Closed'
                    Notes = "Connection to Port Timed Out after $TCPtimeout milliseconds" 
                }
            } Else { 
                Try {
                    [void]$tcpobject.EndConnect($connect) 
                    [pscustomobject]@{
                        Computername = $Computername 
                        Port = $Port 
                        Protocol = "TCP" 
                        State = 'Open'   
                        Notes = $Null  
                    } 
                } Catch {
                    [pscustomobject]@{
                        Computername = $Computername 
                        Port = $Port 
                        Protocol = "TCP" 
                        State = 'Closed'
                        Notes = $_.exception.innerexception.message                             
                    }                        
                }                       
            }    
            #Close connection     
            $tcpobject.Close()
        }
        Function TestUDPPort {
            Param ($Computername,$Port,$UDPtimeout)
            #Create object for connecting to port on computer 
            $udpobject = New-Object Net.Sockets.Udpclient([System.Net.Sockets.AddressFamily]::InterNetwork) 

            #Set a timeout on receiving message
            $udpobject.client.ReceiveTimeout = $UDPTimeout

            #Connect to remote machine's port 
            Try {              
                Write-Verbose "Making UDP connection to remote Computername"
                $udpobject.Connect($Computername,$Port)
            } Catch {
                [pscustomobject]@{
                    Computername = $Computername 
                    Port = $Port 
                    Protocol = "UDP" 
                    State = 'Closed' 
                    Notes = 'Unable to verify host exists'
                }   
                Continue                  
            }

            #Sends a message to the host to which you have connected.
            Write-Verbose "Sending message to remote host"
            $ASCIIEncode = New-Object System.text.asciiencoding
            $byte = $ASCIIEncode.GetBytes("ABCDEFG")
            [void]$udpobject.Send($byte,$byte.length)

            #IPEndPoint object will allow us to read datagrams sent from any source. 
            Write-Verbose "Creating remote endpoint"
            $RemoteEndpoint = New-Object System.net.ipendpoint([system.net.ipaddress]::Any,0)
                    
            Try {
                #Blocks until a message returns on this socket from a remote host.
                Write-Verbose "Waiting for message return"
                $ReceivedBytes = $udpobject.Receive([ref]$RemoteEndpoint)
                [string]$ReturnData = $a.GetString($ReceivedBytes)
                [pscustomobject]@{
                    Computername = $Computername 
                    Port = $Port 
                    Protocol = "UDP" 
                    State = 'Open' 
                    Notes = $Null
                }
            } Catch {
                If ($Error[0].ToString() -match "\bRespond after a period of time\b") {
                    #Make sure that the host is online and not a false positive that it is open
                    If (Test-Connection -comp $Computername -count 1 -quiet) {
                        Write-Verbose "Connection Open"  
                        [pscustomobject]@{
                            Computername = $Computername 
                            Port = $Port 
                            Protocol = "UDP" 
                            State = 'Filtered' 
                            Notes = "Connection to Port Timed Out after $UDPTimeout milliseconds"
                        }
                    }                                          
                } Else {                        
                    [pscustomobject]@{
                        Computername = $Computername 
                        Port = $Port 
                        Protocol = "UDP" 
                        State = 'Closed' 
                        Notes = "Connection Unavailable"   
                    }                         
                }
            }   
            $udpobject.close()         
        }
        #endregion Helper Functions  
    } 
    Process {    
        ForEach ($Computer in $Computername) { 
            ForEach ($_port in $port) { 
                If ($Protocol.Contains('TCP')) {   
                    TestTCPPort -Computername $Computer -Port $_port -Protocol TCP -TCPTimeout $TCPtimeout                   
                }     
                If ($Protocol.Contains('UDP')) {  
                    TestUDPPort -Computername $Computer -Port $_port -Protocol UDP -UDPTimeout $UDPtimeout                   
                }  
            } 
        }                 
    }          
}