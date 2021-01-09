Function Load-PerformanceCounters {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Bug inside of PSScriptAnalyzer')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'I like Load instead of import at the moment')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Directory")][string]$Directory,
        [Parameter(Mandatory = $true, ParameterSetName = "FilePaths")][array]$FilePaths,
        [Parameter(Mandatory = $false)][Int64]$MaxSample = [Int64]::MaxValue,
        [Parameter(Mandatory = $false)][datetime]$StartTime = [datetime]::MinValue,
        [Parameter(Mandatory = $false)][datetime]$EndTime = [datetime]::MaxValue,
        [Parameter(Mandatory = $false)][array]$Counters
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-VerboseWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/PerformanceData/Import-PerformanceCounters/Import-PerformanceCounters.ps1
    #>

    Add-Type @"
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

using Microsoft.PowerShell.Commands.GetCounter;

namespace LoadPerformanceCounters
{
    public class CounterAccuracy
    {
        public double Percentage;
        public int SumDataPoints;
        public int EstimateDataPoints;

        public CounterAccuracy()
        {
            this.Percentage = 0;
            this.SumDataPoints = 0;
            this.EstimateDataPoints = 0;
        }
    }

    public class PerformanceCounterName
    {
        public string FullName;
        public string ServerName;
        public string ObjectName;
        public string InstanceName;
        public string CounterName;

        public PerformanceCounterName()
        {

        }

        public PerformanceCounterName(PerformanceCounterName info)
        {
            this.FullName = info.FullName;
            this.ServerName = info.ServerName;
            this.ObjectName = info.ObjectName;
            this.InstanceName = info.InstanceName;
            this.CounterName = info.CounterName;
        }

        public static PerformanceCounterName GetPerformanceCounterNameFromFullName(string FullName, string SampleInstanceName)
        {
            int endOfServerIndex = FullName.IndexOf("\\",2);
            int startOfCounterIndex = FullName.LastIndexOf("\\") + 1;
            int endOfCounterObjectIndex = FullName.IndexOf("(");
            string instanceName = string.Empty;
            if(endOfCounterObjectIndex == -1)
            {
                endOfCounterObjectIndex = startOfCounterIndex - 1;
            }
            if((FullName.Contains("(")) && (FullName.Contains("#")))
            {
                instanceName = FullName.Substring(endOfCounterObjectIndex + 1, (FullName.IndexOf(")") - endOfCounterObjectIndex -1));
            }
            else
            {
                instanceName = SampleInstanceName;
            }

            PerformanceCounterName performanceCounterNameObj = new PerformanceCounterName
            {
                FullName = FullName,
                ServerName = FullName.Substring(2,(endOfServerIndex - 2)),
                ObjectName = FullName.Substring(endOfServerIndex + 1, endOfCounterObjectIndex - endOfServerIndex - 1),
                InstanceName = instanceName,
                CounterName = FullName.Substring(startOfCounterIndex)
            };

            return performanceCounterNameObj;
        }
    }

    public class CounterData : PerformanceCounterName
    {
        public CounterAccuracy Accuracy;
        public List<PerformanceCounterSample> AllData;
        public int GetDataCount { get { return AllData.Count() - 1;  } }
        public Dictionary<DateTime,PerformanceCounterSample> TimeHash;
        public IEnumerable<PerformanceCounterSample> GetData { get {return AllData.Skip(1); } }
        public PerformanceCounterSample FirstSample {get {return GetData.First(); } }
        public PerformanceCounterSample LastSample {get {return GetData.Last(); } }

        public CounterData()
        {
            this.Accuracy = new CounterAccuracy();
            this.TimeHash = new Dictionary<DateTime,PerformanceCounterSample>();
            this.AllData = new List<PerformanceCounterSample>();
        }

        public CounterData(PerformanceCounterName obj)
            : base(obj)
        {
            this.Accuracy = new CounterAccuracy();
            this.TimeHash = new Dictionary<DateTime,PerformanceCounterSample>();
            this.AllData = new List<PerformanceCounterSample>();
        }

        public CounterData(PerformanceCounterName obj, List<PerformanceCounterSample> data)
            : base(obj)
        {
            this.Accuracy = new CounterAccuracy();
            this.TimeHash = new Dictionary<DateTime,PerformanceCounterSample>();
            //this.AllData = new List<PerformanceCounterSample>();
            this.AllData = data;
            foreach(PerformanceCounterSample datapoint in this.GetData)
            {
                try
                {
                    this.TimeHash.Add(datapoint.Timestamp, datapoint);
                }
                catch
                {
                    //Do nothing, it appears that this sometimes happens, likely due to multiple files in the load
                    //Might need to look into some debug logging to determine if this is going to be an issue or not
                }
            }
        }

    }

    public class PerformanceCounters
    {
        private Array timeKeys;
        private Array counterKeys;
        private Dictionary<string, Dictionary<string, List<string>>> counterKeysGrouping;

        public string ServerName;
        public Dictionary<string, CounterData> AllCounterData;
        public Array GetTimeKeys {get {return this.timeKeys;} }
        public Array GetCounterKeys {get {return this.counterKeys;}}
        public Dictionary<string, Dictionary<string, List<string>>> GetCounterKeysGrouping {get {return this.counterKeysGrouping;}}

        public PerformanceCounters(string ServerName, Dictionary<string, CounterData> AllCounterData, Array TimeKeys, Array CounterKeys, Dictionary<string, Dictionary<string, List<string>>> CounterKeysGrouping)
        {
            this.ServerName = ServerName;
            this.AllCounterData = new Dictionary<string, CounterData>();
            this.AllCounterData = AllCounterData;
            this.timeKeys = TimeKeys;
            this.counterKeys = CounterKeys;
            this.counterKeysGrouping = CounterKeysGrouping;
        }

        private bool TryGetCounterInternal(ref string ObjectName, ref string CounterName)
        {
            ObjectName = ObjectName.ToLower();
            CounterName = CounterName.ToLower();
            if(this.counterKeysGrouping.ContainsKey(ObjectName) &&
                this.counterKeysGrouping[ObjectName].ContainsKey(CounterName))
            {
                return true;
            }
            return false;
        }

        public bool TryGetCounterKey(string ObjectName, string CounterName, string InstanceName, out string Key)
        {
            Key = string.Empty;
            InstanceName = InstanceName.ToLower();
            if(TryGetCounterInternal(ref ObjectName, ref CounterName))
            {
                foreach(string instance in this.counterKeysGrouping[ObjectName][CounterName])
                {
                    if(instance.Contains(InstanceName.ToLower()))
                    {
                        Key = instance;
                        return true;
                    }
                }
                return false;
            }
            else
            {
                return false;
            }
        }

        public bool TryGetCounterKey(string ObjectName, string CounterName, out string Key)
        {
            Key = string.Empty;
            if(TryGetCounterInternal(ref ObjectName, ref CounterName))
            {
                Key = this.counterKeysGrouping[ObjectName][CounterName][0];
                return true;
            }
            else
            {
                return false;
            }
        }

        public bool TryGetCounterInstanceKeys(string ObjectName, string CounterName, out List<string> Keys)
        {
            Keys = new List<string>();
            if(TryGetCounterInternal(ref ObjectName, ref CounterName))
            {
                foreach(string key in this.counterKeysGrouping[ObjectName][CounterName])
                {
                    Keys.Add(key);
                }
                return true;
            }
            return false;
        }

        public static  Dictionary<string, List<PerformanceCounterSample>> GroupPerformanceCounterSamplesByPath(object[] AllCounters)
        {
            Dictionary<string, List<PerformanceCounterSample>> dictionaryGroup = new Dictionary<string, List<PerformanceCounterSample>>();
            int i = 0;
            while(i < AllCounters.Count())
            {
                PerformanceCounterSample datapoint = AllCounters[i++] as PerformanceCounterSample;
                string key = datapoint.Path;
                if(!(dictionaryGroup.ContainsKey(key)))
                {
                    dictionaryGroup.Add(key, new System.Collections.Generic.List<PerformanceCounterSample>());
                }
                dictionaryGroup[key].Add(datapoint);
            }
            return dictionaryGroup;
        }
    }
}
"@ -ReferencedAssemblies "Microsoft.PowerShell.Commands.Diagnostics, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35"

    if ($PSBoundParameters.ContainsKey('Directory')) {
        $FilePaths = (Get-ChildItem $Directory | Where-Object { $_.Extension -eq ".blg" }).VersionInfo.FileName
    }
    foreach ($filePath in $FilePaths) {
        if (!(Test-Path $filePath)) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid files"
        }
    }
    [System.Diagnostics.Stopwatch]$stopWatchTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $importCounters = Import-PerformanceCounters -FilePaths $FilePaths -MaxSample $MaxSample -StartTime $StartTime -EndTime $EndTime -Counters $Counters
    $measureGroupTime = Measure-Command { $hashtableGroup = [LoadPerformanceCounters.PerformanceCounters]::GroupPerformanceCounterSamplesByPath($importCounters) }
    Write-VerboseWriter("[{0}]: Took {1} seconds to group the path data" -f [datetime]::Now, $measureGroupTime.TotalSeconds)
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    [System.Collections.Generic.Dictionary[string, LoadPerformanceCounters.CounterData]]$dictionaryAllCounterData = New-Object 'System.Collections.Generic.Dictionary[string, LoadPerformanceCounters.CounterData]'
    [System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]]$hashtableCounterObjectGrouping = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]]'
    $monitor = New-Object PSCustomObject
    $monitor | Add-Member -MemberType NoteProperty -Name "TimeHashCount" -Value 0
    $monitor | Add-Member -MemberType NoteProperty -Name "Key" -Value ([string]::Empty)
    $monitor | Add-Member -MemberType NoteProperty -Name "ContainsMinValue" -Value $false
    $monitor | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ([string]::Empty)

    #TODO: Add multi threading here.
    foreach ($key in $hashtableGroup.Keys) {
        $counterObj = New-Object LoadPerformanceCounters.CounterData([LoadPerformanceCounters.PerformanceCounterName]::GetPerformanceCounterNameFromFullName($hashtableGroup[$key][0].Path, $hashtableGroup[$key][0].InstanceName), $hashtableGroup[$key])
        $dictionaryAllCounterData.Add($key, $counterObj)
        if ($monitor.ServerName -eq ([string]::Empty)) {
            $monitor.ServerName = $counterObj.ServerName
        } elseif ($monitor.ServerName -ne $counterObj.ServerName) {
            throw "Server Name Mismatch"
        }
        if (!($hashtableCounterObjectGrouping.ContainsKey($counterObj.ObjectName))) {
            $hashtableCounterObjectGrouping.Add($counterObj.ObjectName.ToLower(), (New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'))
        }
        if (!($hashtableCounterObjectGrouping[$counterObj.ObjectName].ContainsKey($counterObj.CounterName))) {
            $hashtableCounterObjectGrouping[$counterObj.ObjectName].Add($counterObj.CounterName.ToLower(), (New-Object System.Collections.Generic.List[string]))
        }
        $hashtableCounterObjectGrouping[$counterObj.ObjectName][$counterObj.CounterName].Add($key)
        if ($counterObj.TimeHash.Count -gt $monitor.TimeHashCount -or
            ($monitor.Key -eq [string]::Empty -or
                $monitor.ContainsMinValue)) {
            $monitor.TimeHashCount = $counterObj.TimeHash.Count
            $monitor.Key = $key
            $monitor.ContainsMinValue = $dictionaryAllCounterData[$monitor.Key].TimeHash.ContainsKey([DateTime]::MinValue)
        }
    }
    $returnObject = New-Object LoadPerformanceCounters.PerformanceCounters(($monitor.ServerName), $dictionaryAllCounterData, ([array]$dictionaryAllCounterData[$monitor.Key].TimeHash.Keys | Sort-Object), ([array]$dictionaryAllCounterData.Keys), $hashtableCounterObjectGrouping)
    Write-VerboseWriter("[{0}]: Additional time taken to add TimeHash {1} seconds" -f [datetime]::Now, $secondsTimeHash)
    Write-VerboseWriter("[{0}]: Finished building objects off the data. Completed in {1} seconds" -f [datetime]::Now, $stopWatch.Elapsed.TotalSeconds)
    Write-VerboseWriter("[{0}]: Total time taken {1} seconds" -f [datetime]::Now, $stopWatchTotal.Elapsed.TotalSeconds)
    return $returnObject
}