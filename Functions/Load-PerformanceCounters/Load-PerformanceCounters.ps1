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

#Function Version 1.5
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-CounterDataObject/New-CounterDataObject.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Group-ObjectHashTable/Group-ObjectHashTable.ps1
#>

Add-Type @"
using System;
using System.Collections;

namespace LoadPerformanceCounters
{
    public class PerformanceCounters
    {
        private Array timeKeys; 
        private Array counterKeys;
        private Hashtable counterKeysGrouping;

        public string ServerName;
        public Hashtable AllData;
        public Array GetTimeKeys {get {return this.timeKeys;} }
        public Array GetCounterKeys {get {return this.counterKeys;}}
        public Hashtable GetCounterKeysGrouping {get {return this.counterKeysGrouping;}}

        public PerformanceCounters(string ServerName, Hashtable AllData, Array TimeKeys, Array CounterKeys, Hashtable CounterKeysGrouping)
        {
            this.ServerName = ServerName;
            this.AllData = AllData;
            this.timeKeys = TimeKeys;
            this.counterKeys = CounterKeys;
            this.counterKeysGrouping = CounterKeysGrouping; 
        }
    }

}
"@

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
$hashtableAllData = @{}
$hashtableCounterObjectGrouping = @{}
$monitor = New-Object PSCustomObject
$monitor | Add-Member -MemberType NoteProperty -Name "TimeHashCount" -Value 0
$monitor | Add-Member -MemberType NoteProperty -Name "Key" -Value ([string]::Empty)
$monitor | Add-Member -MemberType NoteProperty -Name "ContainsMinValue" -Value $false
$monitor | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ([string]::Empty)

#TODO: Add multi threading here.
foreach($key in $hashtableGroup.Keys)
{
    $counterObj =  New-CounterDataObject -PerformanceCounterSamples $hashtableGroup[$key]
    $hashtableAllData.Add($key, $counterObj)
    if($monitor.ServerName -eq ([string]::Empty))
    {
        $monitor.ServerName = $counterObj.ServerName
    }
    elseif($monitor.ServerName -ne $counterObj.ServerName)
    {
        throw "Server Name Mismatch"
    }
    if(!($hashtableCounterObjectGrouping.ContainsKey($counterObj.ObjectName)))
    {
        $hashtableCounterObjectGrouping[$counterObj.ObjectName] = [hashtable]@{}
    }
    if(!($hashtableCounterObjectGrouping[$counterObj.ObjectName].ContainsKey($counterObj.CounterName)))
    {
        $hashtableCounterObjectGrouping[$counterObj.ObjectName][$counterObj.CounterName] = New-Object System.Collections.Generic.List[System.Object]
    }
    $hashtableCounterObjectGrouping[$counterObj.ObjectName][$counterObj.CounterName].Add($key)
    if($counterObj.TimeHash.Count -gt $monitor.TimeHashCount -or
        ($monitor.Key -eq [string]::Empty -or 
        $monitor.ContainsMinValue))
    {
        $monitor.TimeHashCount = $counterObj.TimeHash.Count 
        $monitor.Key = $key
        $monitor.ContainsMinValue = $hashtableAllData[$monitor.Key].TimeHash.ContainsKey([DateTime]::MinValue)
    }
}
$returnObject = New-Object LoadPerformanceCounters.PerformanceCounters(($monitor.ServerName), $hashtableAllData, ([array]$hashtableAllData[$monitor.Key].TimeHash.Keys | Sort-Object), ([array]$hashtableAllData.Keys), $hashtableCounterObjectGrouping)
Write-VerboseWriter("[{0}]: Additional time taken to add TimeHash {1} seconds" -f [datetime]::Now, $secondsTimeHash)
Write-VerboseWriter("[{0}]: Finished building objects off the data. Completed in {1} seconds" -f [datetime]::Now, $stopWatch.Elapsed.TotalSeconds)
Write-VerboseWriter("[{0}]: Total time taken {1} seconds" -f [datetime]::Now, $stopWatchTotal.Elapsed.TotalSeconds)
return $returnObject
}