#region Synchronized Collections
$runspace = [hashtable]::Synchronized(@{})
$ui = [hashtable]::Synchronized(@{})
$jobCleanup = [hashtable]::Synchronized(@{})
$jobs = [collections.arraylist]::Synchronized([collections.arraylist]@())
$collection = [hashtable]::Synchronized(@{})
#endregion Synchronized Collections

#region Extra things for Sync'ed Collections
$collection.ObservableCollection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
$jobCleanup.Flag = $True
#endregion Extra things for Sync'ed Collections

#region UI Runspace Creation
$runspace.Runspace =[runspacefactory]::CreateRunspace()
$runspace.Runspace.ApartmentState = "STA"         
$runspace.Runspace.Open()         
$runspace.Runspace.SessionStateProxy.SetVariable("runspace",$runspace)     
$runspace.Runspace.SessionStateProxy.SetVariable("ui",$ui) 
$runspace.Runspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$runspace.Runspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$runspace.Runspace.SessionStateProxy.SetVariable("collection",$collection)     
$runspace.PowerShell = [powershell]::Create().AddScript({
    $ui.Error = $Error
    #region Build the GUI
    [xml]$xaml = @"
    <Window
        xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        x:Name='Window' Title='' WindowStartupLocation = 'CenterScreen' 
        Width = '880' Height = '590' ShowInTaskbar = 'True'>
        <Window.Background>
            <LinearGradientBrush StartPoint='0,0' EndPoint='0,1'>
                <LinearGradientBrush.GradientStops>
                    <GradientStop Color='#C4CBD8' Offset='0' />
                    <GradientStop Color='#E6EAF5' Offset='0.2' />
                    <GradientStop Color='#CFD7E2' Offset='0.9' />
                    <GradientStop Color='#C4CBD8' Offset='1' />
                </LinearGradientBrush.GradientStops>
            </LinearGradientBrush>
        </Window.Background>
        <Window.Resources>
            <DataTemplate x:Key="HeaderTemplate">
                <DockPanel>
                    <TextBlock FontSize="10" Foreground="Green" FontWeight="Bold" >
                        <TextBlock.Text>
                            <Binding/>
                        </TextBlock.Text>
                    </TextBlock>
                </DockPanel>
            </DataTemplate>
        </Window.Resources>
        <Grid ShowGridLines = 'False'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = 'Auto'/>
                <RowDefinition Height = 'Auto'/>
            </Grid.RowDefinitions>
            <GroupBox Header = "Some List" Grid.Column = '0' Grid.Row = '0' Height = "510">
                <Grid Width = 'Auto' Height = 'Auto' ShowGridLines = 'false'>
                <Grid.Resources>
                    <Style x:Key="AlternatingRowStyle" TargetType="{x:Type Control}" >
                        <Setter Property="Background" Value="LightGray"/>
                        <Setter Property="Foreground" Value="Black"/>
                        <Style.Triggers>
                            <Trigger Property="ItemsControl.AlternationIndex" Value="1">
                                <Setter Property="Background" Value="White"/>
                                <Setter Property="Foreground" Value="Black"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </Grid.Resources>
                    <ListView x:Name = 'Listview' AllowDrop = 'True' AlternationCount="2" ItemContainerStyle="{StaticResource AlternatingRowStyle}">
                        <ListView.View>
                            <GridView x:Name = 'GridView' AllowsColumnReorder = 'True' ColumnHeaderTemplate="{StaticResource HeaderTemplate}">
                                <GridViewColumn x:Name = 'PID' Width = '110' DisplayMemberBinding = '{Binding Path = PID}' Header='PID'/>
                                <GridViewColumn x:Name = 'ThreadID' Width = '110' DisplayMemberBinding = '{Binding Path = ThreadID}' Header='ThreadID'/>
                                <GridViewColumn x:Name = 'ThreadCount' Width = '110' DisplayMemberBinding = '{Binding Path = ThreadCount}' Header='ThreadCount' />
                                <GridViewColumn x:Name = 'TimeStart' Width = '110' DisplayMemberBinding = '{Binding Path = TimeStart}' Header='TimeStart' />
                                <GridViewColumn x:Name = 'HostLookup' Width = '110' DisplayMemberBinding = '{Binding Path = HostLookup}' Header='HostLookup' />
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </GroupBox>
            <Button x:Name = 'Go_btn' Grid.Column = '0' Grid.Row = '1' Width = "50" Height = "25">
                GO!
            </Button>
            <ProgressBar x:Name="progressbar" Grid.Column = "0" Grid.Row = "2" Height = "15" Maximum='10'/>
        </Grid>
    </Window>
"@
    #endregion Build the GUI

    #region Background runspace to clean up jobs
    $newRunspace =[runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"         
    $newRunspace.Open()         
    $newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
    $newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
    $newRunspace.SessionStateProxy.SetVariable("ui",$ui) 
    $jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
        #Routine to handle completed runspaces
        Do {    
            [System.Threading.Monitor]::Enter($Jobs.syncroot)
            Foreach($runspace in $jobs) {
                If ($runspace.Handle.isCompleted) {
                    $runspace.powershell.EndInvoke($runspace.Handle) | Out-Null
                    $runspace.powershell.dispose()
                    $runspace.Handle = $null
                    $runspace.powershell = $null               
                } 
            }
            #Clean out unused runspace jobs
            $temphash = $jobs.clone()
            $temphash | Where {
                $_.runspace -eq $Null
            } | ForEach {
                $jobs.remove($_)
            }        
            [System.Threading.Monitor]::Exit($Jobs.syncroot)
            Start-Sleep -Seconds 1     
        } while ($jobCleanup.Flag)
    })
    $jobCleanup.PowerShell.Runspace = $newRunspace
    $jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()  
    #endregion

    #region Connect to Controls
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    $ui.Window=[Windows.Markup.XamlReader]::Load( $reader )

    $ui.Button = $ui.Window.FindName('Go_btn')
    $ui.GridView = $ui.Window.FindName('GridView')
    $ui.ListView = $ui.Window.FindName('Listview')
    $ui.ProgressBar = $ui.Window.FindName('progressbar')

    #endregion Connect to Controls

    #region UI Events
    $ui.Window.Add_Loaded({
        $ui.ListView.ItemsSource = $collection.ObservableCollection
    })

    $ui.Button.Add_Click({ 
        $ui.ProgressBar.Value = 0
        $ps = [powershell]::Create().AddScript({ 
            Param ($Collection, $ui, $jobs)   
            $RunspacePool = [runspacefactory]::CreateRunspacePool(1,5) 
            $ScriptBlock = {
                Param ($ui, $Collection)
                $HostLookup = [net.dns]::GetHostAddresses('google.com') | Select -Expand IPAddressToString
                $Object = [pscustomobject]@{
                    PID = $PID
                    ThreadID = ([System.Threading.Thread]::CurrentThread.ManagedThreadId)
                    ThreadCount = (Get-Process -ID $PID).Threads.Count
                    TimeStart = (Get-Date).ToString()
                    HostLookup = $HostLookup | Out-String
                }
                Start-Sleep -Seconds (Get-Random -input (1..5))
                $ui.GridView.Dispatcher.Invoke('Normal',[action]{
                    [void]$collection.observableCollection.Add($Object)
                    #[void]$ui.listview.itemssource.add($Object)
                    $ui.ProgressBar.Value++
                })
                           
            }
            1..15 | ForEach {
                $ps = [powershell]::Create()
                $ps.RunspacePool = $RunspacePool
                $RunspacePool.Open()  
                [void]$ps.AddScript($ScriptBlock).AddArgument($ui).AddArgument($Collection)
                [void]$jobs.Add([pscustomobject]@{
                    PowerShell = $Ps
                    Handle = $PS.BeginInvoke()
                })
            } 
        }).AddArgument($Collection).AddArgument($ui).AddArgument($jobs)   

        [System.Threading.Monitor]::Enter($Jobs.syncroot)
        $jobs.Add([pscustomobject]@{
            PowerShell = $ps
            Handle = $Ps.BeginInvoke()
        })
        [System.Threading.Monitor]::Exit($Jobs.syncroot)
    })

    $ui.Window.Add_Closed({
        #Halt job processing
        $jobCleanup.Flag = $False

        #Stop all runspaces
        $jobCleanup.PowerShell.Dispose()
    
        $runspace.PowerShell.Runspace.Close()
        $runspace.PowerShell.Dispose()

        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    })
    #endregion UI Events

    [void]$ui.Window.ShowDialog()
})
$runspace.PowerShell.Runspace = $runspace.Runspace
$runspace.Handle = $runspace.PowerShell.BeginInvoke()
#endregion UI Runspace Creation

