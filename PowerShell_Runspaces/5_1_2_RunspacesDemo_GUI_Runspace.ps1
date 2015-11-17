$uiHash = [hashtable]::Synchronized(@{})
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("uiHash",$uiHash)          
$psCmd = [PowerShell]::Create().AddScript({   
    $uiHash.Error = $Error
    [xml]$xaml = @"
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window" Title="Initial Window" WindowStartupLocation = "CenterScreen"
        Width = "650" Height = "800" ShowInTaskbar = "True">
        <TextBox x:Name = "textbox" Height = "400" Width = "600"/>
    </Window>
"@
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    $uiHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
    $uiHash.TextBox = $uiHash.window.FindName("textbox")
    $uiHash.Window.ShowDialog() | Out-Null
})
$psCmd.Runspace = $newRunspace
$handle = $psCmd.BeginInvoke()

#-----------------------------------------

#Using the Dispatcher to send data from another thread to UI thread
$uiHash.Window.Dispatcher.invoke("Normal",[action]{$uiHash.Window.Background='Green'})


Function Update-Window {
    Param (
        $Title,
        $Content,
        [switch]$AppendContent
    )
    $uiHash.Window.Dispatcher.invoke("Normal",[action]{
        $uiHash.Window.Title = $title
        If ($PSBoundParameters['AppendContent']) {
            $uiHash.TextBox.AppendText($Content)
        } Else {
            $uiHash.TextBox.Text = $Content
        }
    })
}
 



1..10 | % {
    If ($_%2) {
        Update-Window -Title ("Services on {0}" -f $Env:Computername) -Content (Get-Service | Sort Status -Desc| out-string)    
        $uiHash.Window.Dispatcher.invoke("Normal",[action]{$uiHash.Window.Background='Black'})
    } Else {
        Update-Window -Title ("Processes on {0}" -f $Env:Computername) -Content (Get-Process | Sort Status -Desc| out-string)
        $uiHash.Window.Dispatcher.invoke("Normal",[action]{$uiHash.Window.Background='White'})
    }
}

$psCmd.EndInvoke($handle)
$psCmd.Dispose()