Function Load-PerformanceCounters {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true,ParameterSetName="Directory")][string]$Directory,
[Parameter(Mandatory=$true,ParameterSetName="FilePaths")][array]$FilePaths,
[Parameter(Mandatory=$false)][Int64]$MaxSample = [Int64]::MaxValue, 
[Parameter(Mandatory=$false)][datetime]$StartTime = [datetime]::MinValue, 
[Parameter(Mandatory=$false)][datetime]$EndTime = [datetime]::MaxValue,
[Parameter(Mandatory=$false)][array]$Counters
)

#Function Version 1.4
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-CounterDataObject/New-CounterDataObject.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Group-ObjectHashTable/Group-ObjectHashTable.ps1
#>
if($PSBoundParameters.ContainsKey('Directory'))
{
    $FilePaths = (Get-ChildItem $Directory | ?{$_.Extension -eq ".blg"}).VersionInfo.FileName
}
foreach($filePath in $FilePaths)
{
    if(!(Test-Path $filePath))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid files"
    }
}
[System.Diagnostics.Stopwatch]$stopWatchTotal = [System.Diagnostics.Stopwatch]::StartNew()
$importCounters = Import-PerformanceCounters -FilePaths $FilePaths -MaxSample $MaxSample -StartTime $StartTime -EndTime $EndTime -Counters $Counters 
$measureGroupTime = Measure-Command { $hashtableGroup = $importCounters | Group-ObjectHashTable Path }
Write-VerboseWriter("[{0}]: Took {1} seconds to group the path data" -f [datetime]::Now, $measureGroupTime.TotalSeconds)
[System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$hashtable = @{}
foreach($key in $hashtableGroup.Keys)
{
    $counterObj =  New-CounterDataObject -PerformanceCounterSamples $hashtableGroup[$key]
    $hashtable.Add($key, $counterObj)
}
Write-VerboseWriter("[{0}]: Additional time taken to add TimeHash {1} seconds" -f [datetime]::Now, $secondsTimeHash)
Write-VerboseWriter("[{0}]: Finished building objects off the data. Completed in {1} seconds" -f [datetime]::Now, $stopWatch.Elapsed.TotalSeconds)
Write-VerboseWriter("[{0}]: Total time taken {1} seconds" -f [datetime]::Now, $stopWatchTotal.Elapsed.TotalSeconds)
return $hashtable
}