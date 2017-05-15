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
$Window=[Windows.Markup.XamlReader]::Load( $reader )
$TextBox = $window.FindName("textbox")
$Window.ShowDialog() | Out-Null