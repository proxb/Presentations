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
            <ProgressBar x:Name="progressbar" Grid.Column = "0" Grid.Row = "2" Height = "15" Maximum='15'/>
        </Grid>
    </Window>
"@
#endregion Build the GUI

#region Connect to Controls
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load( $reader )

$Button = $Window.FindName('Go_btn')
$GridView = $Window.FindName('GridView')
$ListView = $Window.FindName('Listview')
$ProgressBar = $Window.FindName('progressbar')

#endregion Connect to Controls

#region UI Events
$Window.Add_Loaded({
    $Script:observableCollection = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $ListView.ItemsSource = $observableCollection
})

$Button.Add_Click({
    $ProgressBar.Value = 0
    1..15 | % {
        Write-Verbose "Looking up data" -Verbose
        $HostLookup = [net.dns]::GetHostAddresses('google.com') | Select -Expand IPAddressToString
        $Object = [pscustomobject]@{
            PID = $PID
            ThreadID = ([System.Threading.Thread]::CurrentThread.ManagedThreadId)
            ThreadCount = (Get-Process -ID $PID).Threads.Count
            TimeStart = (Get-Date).ToString()
            HostLookup = $HostLookup | Out-String
        }
        Start-Sleep -Seconds (Get-Random -input (1..5))            
        $window.Dispatcher.Invoke('Normal',[action] {
            [void]$Script:observableCollection.Add($Object) 
            $ProgressBar.Value++
            $window.UpdateLayout()
        })
    }
})
#endregion UI Events

[void]$Window.ShowDialog()