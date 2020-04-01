Function Import-PerformanceCounters {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Directory,
[Parameter(Mandatory=$false)][Int64]$MaxSample = [Int64]::MaxValue, 
[Parameter(Mandatory=$false)][datetime]$StartTime = [datetime]::MinValue, 
[Parameter(Mandatory=$false)][datetime]$EndTime = [datetime]::MaxValue,
[Parameter(Mandatory=$false)][array]$Counters
)

#Function Version 1.3
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
#>
<#
    When passing something like \\*\Process(*)\* we see a dramatic decrease in performance of reading the file. In a 1 GB file we see a decrease of performance by a few minutes vs providing all the values for the counters in Process
    For example: "\\*\Process(*)\% Privileged Time","\\*\Process(*)\% Processor Time","\\*\Process(*)\% User Time","\\*\Process(*)\Creating Process ID",..... so on
#>
<#
TODO:
- Remove directory parameter, instead use FilePath. This way the user has the control prior to this function on how to use it
- Remove the array in Get-FastCounterNames 
#>
Function Get-FastCounterNames {
param(
[Parameter(Mandatory=$true)][array]$FilePaths 
)
    Write-VerboseWriter("Getting the Counter Names vs using wild card as this has better performance")
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $myParmas = @{
        Path = $FilePaths
        StartTime = $StartTime
        EndTime = $EndTime
        MaxSample = 2
        ErrorAction = "SilentlyContinue"
        Verbose = $false 
        Counter = $Counters
    }
    
    $measureImport = Measure-Command {$results = (Import-Counter @myParmas).CounterSamples}
    Write-VerboseWriter("Took {0} seconds to import" -f $measureImport.TotalSeconds)

    $measureGroup = Measure-Command { $groupResults = $results | Group-Object Path }
    Write-VerboseWriter("Took {0} seconds to group the results" -f $measureGroup.TotalSeconds)

    $masterCounterList = @() 
    foreach($counterGroup in $groupResults)
    {
        $inList = $false
        $counterName = $counterGroup.Name 
        foreach($counterCheck in $masterCounterList)
        {
            if($counterName -like $counterCheck)
            {
                $inList = $true 
                break; 
            }
        }
        if($inList)
        {
            continue 
        }
        $counterNameObj = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $counterGroup.Group[0]
        if([string]::IsNullOrEmpty($counterNameObj.InstanceName))
        {
            $addCounter = "\\*\{0}\{1}"
        }
        else 
        {
            $addCounter = "\\*\{0}(*)\{1}"    
        }
        $addCounter = $addCounter -f $counterNameObj.ObjectName, $counterNameObj.CounterName
        $masterCounterList += $addCounter
    }
    $stopWatch.Stop()
    Write-VerboseWriter("Finished getting the counter list in {0} seconds" -f $stopWatch.Elapsed.TotalSeconds)
    return $masterCounterList
}

########## Parameter Binding Exceptions ##############

if(-not(Test-Path $Directory))
{
    $displayError = "Failed to provide valid Directory. '{0}'" -f $Directory
    throw [System.Management.Automation.ParameterBindingException] $displayError
}
if($StartTime -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid StartTime"
}
if($EndTime -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EndTime"
}
if($MaxSample -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSample"
}
if(($files = Get-ChildItem $Directory | ?{$_.Extension -eq ".blg"}) -eq $null)
{
    throw "No files in the directory"
}

$filePaths = @()

foreach($file in $files)
{
    $filePaths += $file.VersionInfo.FileName
}

$params = @{
    Path = $filePaths
    StartTime = $StartTime
    EndTime = $EndTime
    MaxSample = $MaxSample
    ErrorAction = "SilentlyContinue"
    Verbose = $false 
}

if($Counters -ne $null -and $Counters.count -gt 0)
{
    $fastCounters = Get-FastCounterNames -FilePaths ($filePaths[0])
    $params.Add("Counter", $fastCounters)
}

$totalSize = 0
Write-VerboseWriter("Importing files from batch list")
foreach($file in $filePaths)
{
    Write-VerboseWriter("File Size {0}MB. File Name: {1}." -f ($size = (Get-Item $file).Length / 1MB), $file )
    $totalSize += $size
}
[System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$importCounters = (Import-Counter @params).CounterSamples
Write-VerboseWriter("Took {0} seconds to import this batch size of {1}MB for {2} datapoints." -f $stopWatch.Elapsed.TotalSeconds, $totalSize, $importCounters.count)
return $importCounters
}