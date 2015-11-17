# Working with Excel and Word for reporting can be somewhat challenging; requires some exploration
# Step through function to show how to use Excel/Word COM objects to build report
$File = 'C (OS Disk).csv'
#region Helper Functions
Function New-DriveSpaceTrendReport {
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True)]
        [Alias('Fullname')]
        [string[]]$CSVFile,
        [parameter()]
        [string]$Destination = "$PWD\TrendReport.doc",
        [string]$Title = "Drive Space Trend Report"
    )
    Begin {
        If ($PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = 'Continue'
        }
        $PSBoundParameters.GetEnumerator()|ForEach {
            Write-Debug $_
        }
        #region Helper Functions
        Function New-WordText {
            [cmdletbinding()]
            Param (
                [string]$Text,
                [int]$Size = 11,
                [string]$Style = 'Normal',
                [Microsoft.Office.Interop.Word.WdColor]$ForegroundColor = "wdColorAutomatic",
                [switch]$Bold,
                [switch]$Italic,
                [switch]$NoNewLine,
                [Microsoft.Office.Interop.Word.WdParagraphAlignment]$Alignment='wdAlignParagraphLeft'
            )  
            Try {
                $Selection.Style = $Style
            } Catch {
                Write-Warning "Style: `"$Style`" doesn't exist! Try another name."
                Break
            } 
            #Set alignment
            $Selection.ParagraphFormat.Alignment=$Alignment
            If ($Style -notmatch 'Title|^Heading'){
                $Selection.Font.Size = $Size            
                $Selection.Font.Color = $ForegroundColor
            }

            If ($PSBoundParameters.ContainsKey('Bold')) {
                $Selection.Font.Bold = 1
            } Else {
                $Selection.Font.Bold = 0
            }
            If ($PSBoundParameters.ContainsKey('Italic')) {
                $Selection.Font.Italic = 1
            } Else {
                $Selection.Font.Italic = 0
            }

            $Selection.TypeText($Text)

            If (-NOT $PSBoundParameters.ContainsKey('NoNewLine')) {
                $Selection.TypeParagraph()
            }
        }
        Function New-WordTable {
            [cmdletbinding(
                DefaultParameterSetName='Table'
            )]
            Param (
                [parameter()]
                [object]$Object,
                [parameter(ParameterSetName='Table')]
                [switch]$AsTable,
                [parameter(ParameterSetName='List')]
                [switch]$AsList,
                [parameter()]
                [string]$TableStyle,
                [parameter()]
                [Microsoft.Office.Interop.Word.WdDefaultTableBehavior]$TableBehavior = 'wdWord9TableBehavior',
                [parameter()]
                [Microsoft.Office.Interop.Word.WdAutoFitBehavior]$AutoFitBehavior = 'wdAutoFitContent'
            )
            $Range = @($Selection.Paragraphs)[-1].Range    

            Switch ($PSCmdlet.ParameterSetName) {
                'Table' {
                    $text=($Object | ConvertTo-Csv -NoTypeInformation | Out-String) -replace '"'
                    $Range.Text = “$text”
                    $separator=[Microsoft.Office.Interop.Word.WdTableFieldSeparator]::wdSeparateByCommas
                    $table=$Range.ConvertToTable($separator)
                    If (-NOT $PSBoundParameters.ContainsKey('TableStyle')) { 
                        Write-Verbose "Setting table style" 
                        $table.Style = "Medium Shading 1 - Accent 1"                      
                    }                 
                    #Fix up table so we don't have weird bolding in first column
                    Write-Verbose "Adjusting Column/Row configuration"
                    $table.ApplyStyleColumnBands = $False
                    $table.ApplyStyleRowBands = $False
                    $table.ApplyStyleHeadingRows = $True
                    $table.ApplyStyleFirstColumn = $False
                }
                'List' {
                    #Specifying 0 index ensures we get accurate data from a single object 
                    $Properties = $Object[0].psobject.properties.name
                    $table = $Selection.Tables.add($Selection.Range,$Properties.count,2,$TableBehavior, $AutoFitBehavior)
                       
                    If (-NOT $PSBoundParameters.ContainsKey('TableStyle')) {
                        $table.Style = "Light Shading - Accent 1"
                    }            
                    $r = 1
                    $Properties | ForEach {
                        $table.cell($r,1).range.Bold=1
                        $table.cell($r,1).range.text = $_
                        $table.cell($r,2).range.Bold=0
                        $table.cell($r,2).range.text = $Object.$_
                        $r++
                    }
                }
            }
            $Word.Selection.Start = $Document.Content.End
            $Selection.TypeParagraph()
        }
        #endregion Helper Functions

        #region Create COM Objects
        Try {
            #Create word COM Object
            Write-Verbose "Initializing Word and Excel COM objects"
            $word = New-Object -ComObject word.application
            #$word.visible = $True
            $Script:Document = $word.Documents.Add()
            $Script:Selection = $Word.Selection
            $SaveFormat = [microsoft.office.interop.word.WdSaveFormat]

            $Document.PageSetup.LeftMargin = 36
            $Document.PageSetup.RightMargin = 36

            #Create excel COM object
            $excel = New-Object -ComObject excel.application

            #Make Visible
            #$excel.Visible = $True

            $excel.DisplayAlerts = $False

        } Catch {
            Write-Warning "$($_.exception.message)"
            Break
        }
        #endregion Create COM Objects

        #region Enums
        $xlDirection=[Microsoft.Office.Interop.Excel.XLDirection]
        $excelChart = [Microsoft.Office.Interop.Excel.XLChartType]
        $excelAxes = [Microsoft.Office.Interop.Excel.XlAxisType]
        $excelCategoryScale = [Microsoft.Office.Interop.Excel.XlCategoryType]
        $excelTickMark = [Microsoft.Office.Interop.Excel.XlTickMark] 
        $WDPaste = [Microsoft.Office.Interop.Word.WdRecoveryType]
        #endregion Enums

        #region Word Header
        New-WordText -Text $Title -Style 'Title' -Bold -Alignment wdAlignParagraphCenter
        #endregion Word Header
    }
    Process {
        ForEach ($file in $CSVFile) {
            If ($file -notmatch '.*\.csv') {
                Write-Warning "$($File) is not a valid CSV file!"
                Return
            }
            Write-Verbose "Attempt to resolve $($File)"
            $File = (Convert-Path $File)
            $DataType = $file -replace '.*\\(.*)\..*','$1'
            #Add CSV File into Excel Workbook
            [void]$excel.Workbooks.Open($File) 

            Write-Verbose "Formatting data"
            $worksheet = $excel.ActiveSheet
            [void]$worksheet.UsedRange.EntireColumn.AutoFit()

            #Column B => Date
            $XLrange = $worksheet.Range("B2")
            $XLselection = $worksheet.Range($XLrange,$XLrange.end($xlDirection::xlDown))
            $DateStart = @($XLselection)[0].Text
            $DateEnd = @($XLselection)[-1].Text

            #Column C => TotalUsed
            $XLrange = $worksheet.Range("C2")
            $XLselection = $worksheet.Range($XLrange,$XLrange.end($xlDirection::xlDown))
            $TotalUsedStart = @($XLselection)[0].Text
            $TotalUsedEnd = @($XLselection)[-1].Text

            #Column D => TotalCapacity
            $XLrange = $worksheet.Range("D2")
            $XLselection = $worksheet.Range($XLrange,$XLrange.end($xlDirection::xlDown))
            $TotalCapStart = @($XLselection)[0].Text
            $TotalCapEnd = @($XLselection)[-1].Text

            Write-Verbose "Creating Excel chart"
            $chart = $worksheet.Shapes.AddChart().Chart
            $worksheet.shapes.item('Chart 1').Name = $DataType
            $worksheet.shapes.item($DataType).Width = 542
            $worksheet.shapes.item($DataType).Height = 240

            $chart.chartType = $excelChart::XlLine
            $chart.HasLegend = $true
            $chart.HasTitle = $true
            $chart.ChartTitle.Text = "$DataType Drive Trend`n $((Get-Date $DateStart).ToShortDateString()) - $((Get-Date $DateEnd).ToShortDateString())"

            $xaxis = $chart.Axes($excelAxes::XlCategory)                                      
            $xaxis.HasTitle = $False 
            $xaxis.CategoryType = $excelCategoryScale::xlCategoryScale 
            $xaxis.MajorTickMark = $excelTickMark::xlTickMarkCross
            $xaxis.AxisBetweenCategories = $False
            $xaxis.TickLabels.NumberFormat = "m/d/yyyy"

            ##Column B => Date
            $chart.SeriesCollection(1).Formula = ($chart.SeriesCollection(1).Formula -replace [regex]::Escape('$A'),'$B')
                                                
            $yaxis = $chart.Axes($excelAxes::XlValue)
            $yaxis.HasTitle = $true                                                        
            $yaxis.AxisTitle.Text = "Size (GB)"
            $yaxis.AxisTitle.Font.Size = 16

            #region Copy Chart
            Write-Verbose "Copying chart to Word document"
            $worksheet.ChartObjects().Item(1).copy()
            $word.Selection.PasteAndFormat($WDPaste::wdChartPicture)
            #endregion Copy Chart

            #region Add Table
            Write-Verbose "Adding table to Word document"
            $Word.Selection.Start = $Document.Content.End
            $Selection.TypeParagraph()
            $Object = [pscustomobject]@{
                InitialUsed = "$TotalUsedStart GB"
                CurrentUsed = "$TotalUsedEnd GB"
                InitialCapacity = "$TotalCapStart GB"
                CurrentCapacity = "$TotalCapEnd GB"
                'Used +/-' = "$([math]::Round(($TotalUsedEnd - $TotalUsedStart),2)) GB"
                'Capacity +/-' = "$([math]::round(($TotalCapEnd - $TotalCapStart),2)) GB"
            }
            New-WordTable -Object $Object -AsTable
            #endregion Add Table

            #region Close Workbook
            $excel.Workbooks.Close()
            #endregion Close Workbook
        }
    }
    End {
        #Ensure that we let Word complete the table style configuration before closing up
        Start-Sleep -Seconds 1
        #region Save Close everything up
        Write-Verbose "Saving Word document <$($Destination)>"
        $Document.SaveAs([ref]$Destination,[ref]$SaveFormat::wdFormatDocument)
        $word.Quit()
        $excel.Quit()
        #endregion Save Close everything up

        #region Cleanup
        Write-Verbose "Performing cleanup actions"
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$excel) 
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$word)
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Remove-Variable excel,word -ErrorAction SilentlyContinue
        #endregion Cleanup
    }
}
#endregion Helper Functions

## Set Visibility back to $False

#region Generate the trend report
$TrendParams = @{
    Destination = "$PWD\Boe-PC_Report.doc"
    Title = "Boe-PC_Trend_Report"
    Verbose = $True
}
Get-ChildItem -Filter *.csv | New-DriveSpaceTrendReport @TrendParams
#endregion Generate the trend report