#region Demo PoshRSJob
#region $Using Variable and Pipeline Support
$Test = 'test'
$Something = 1..10
1..5|start-rsjob -Name {$_} -ScriptBlock {
    [pscustomobject]@{
        Result=($_*2)
        Test=$Using:Test
        Something=$Using:Something
    }
} -Throttle 2

#Check status
Get-RSJob

#Get the results
Get-RSJob|Receive-RSJob|Format-Table

#Remove Jobs
Get-RSJob | Remove-RSJob
#endregion $Using Variable and Pipeline Support

#region Demo Module and Function Support
#region Module
Start-RSJob -Name ModuleTest -ScriptBlock {Get-Module IEFavorites,Pester} -ModulesToImport IEFavorites,Pester | 
Wait-RSJob | Receive-RSJob

Get-RSJob | Remove-RSJob
#endregion Module

#region Custom Function
Function ConvertTo-Hex {
    Param(
        [parameter(ValueFromPipeline=$True)]
        [int]$Number
    )
    Process {
        '0x{0:x}' -f $Number
    }
}
10..20 | Start-RSJob -ScriptBlock {$_ | ConvertTo-Hex} -FunctionsToLoad ConvertTo-Hex | 
Wait-RSJob | Receive-RSJob

Get-RSJob | Remove-RSJob
#endregion Custom Function
#endregion Demo Module and Function Support

#region Demo Wait-RSJob with Progress bar
Function Convert-Size {
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias("Length")]
        [int64]$Size
    )
    Begin {
        If (-Not $ConvertSize) {
            Write-Verbose ("Creating signature from Win32API")
            $Signature =  @"
                 [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
                 public static extern long StrFormatByteSize( long fileSize, System.Text.StringBuilder buffer, int bufferSize );
"@
            $Global:ConvertSize = Add-Type -Name SizeConverter -MemberDefinition $Signature -PassThru
        }
        Write-Verbose ("Building buffer for string")
        $stringBuilder = New-Object Text.StringBuilder 1024
    }
    Process {
        Write-Verbose ("Converting {0} to upper most size" -f $Size)
        $ConvertSize::StrFormatByteSize( $Size, $stringBuilder, $stringBuilder.Capacity ) | Out-Null
        $stringBuilder.ToString()
    }
}

Get-ChildItem $PWD -Directory | Start-RSJob -Name {$_.Name} -ScriptBlock {
    [int64]$Bytes = (Get-ChildItem -Path $_.FullName -Force -Recurse | Measure-Object -Property length -Sum).Sum
    [pscustomobject]@{
        Name = $_.Name
        Size = Convert-Size -Size $Bytes
        Size_bytes = $Bytes
    }
    Start-Sleep -Seconds (Get-Random -InputObject (1..5))
} -FunctionsToLoad Convert-Size -Throttle 5 | Wait-RSJob -ShowProgress |
Receive-RSJob | Sort-Object -Property Size_bytes -Descending

Get-RSJob | Remove-RSJob 
#endregion Demo Wait-RSJob with Progress bar

#endregion Demo PoshRSJob