[CmdletBinding()]
param(
[Parameter(Mandatory=$true,ParameterSetName="Directory")][string]$Directory,
[Parameter(Mandatory=$true,ParameterSetName="FilePath")][string]$FilePath
)
$scriptName = "PerformanceDataClientProtocolAnalyzer"
$counters = @("\\*\.NET CLR LocksAndThreads(*)\Contention Rate / Sec",
    "\\*\.NET CLR Memory(*)\% Time in GC",
    "\\*\.NET CLR Memory(*)\Process ID",
    "\\*\ASP.NET Applications(*)\Requests Executing",
    "\\*\ASP.NET Applications(*)\Requests Total",
    "\\*\Process(*)\% Processor Time",
    "\\*\Process(*)\% Privileged Time",
    "\\*\Process(*)\ID Process",
    "\\*\Processor(*)\% Processor Time",
    "\\*\Processor(*)\% Privileged Time",
    "\\*\System\Processor Queue Length",
    "\\*\System\Context Switches/sec",
    "\\*\W3SVC_W3WP(*)\Active Requests",
    "\\*\W3SVC_W3WP(*)\Requests / Sec")

#############################
#
# Template Functions 
#
#############################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-ExchangeClientProtocolMappings/Get-ExchangeClientProtocolMappings.ps1
Function Get-ExchangeClientProtocolMappings {

#Function Version 1.0
Function New-ClientProtocolMapping {
param(
[string]$FastName,
[string]$AppPoolName,
[string]$AspCounterName
)
    $obj = New-Object PSCustomObject
    $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $FastName
    $obj | Add-Member -MemberType NoteProperty -Name "AppPoolName" -Value $AppPoolName
    $obj | Add-Member -MemberType NoteProperty -Name "AspCounterName" -Value $AspCounterName
    $obj | Add-Member -MemberType NoteProperty -Name "PossiblePIDs" -Value (New-Object 'System.Collections.Generic.List[double]')
    $obj | Add-Member -MemberType NoteProperty -Name "CurrentPid" -Value 0
    $obj | Add-Member -MemberType NoteProperty -Name "ProcessKey" -Value ([string]::Empty)
    $obj | Add-Member -MemberType NoteProperty -Name "NETKey" -Value ([string]::Empty)
    return $obj 
}
        
$clientProtocolMappings = @{}
$clientProtocolMappings.Add("AutoDFe", (New-ClientProtocolMapping -FastName "AutoDFe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Autodiscover"))
$clientProtocolMappings.Add("AutoDBe", (New-ClientProtocolMapping -FastName "AutoDBe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Autodiscover"))
$clientProtocolMappings.Add("EcpFe", (New-ClientProtocolMapping -FastName "EcpFe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_ecp"))
$clientProtocolMappings.Add("EcpBe", (New-ClientProtocolMapping -FastName "EcpBe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_ecp"))
$clientProtocolMappings.Add("MapiAddBook", (New-ClientProtocolMapping -FastName "MapiAddBook" -AppPoolName "MSExchangeMapiAddressBookAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_nspi"))
$clientProtocolMappings.Add("MapiFe", (New-ClientProtocolMapping -FastName "MapiFe" -AppPoolName "MSExchangeMapiFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_mapi"))
$clientProtocolMappings.Add("MapiBe", (New-ClientProtocolMapping -FastName "MapiBe" -AppPoolName "MSExchangeMapiMailboxAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_emsmdb"))
$clientProtocolMappings.Add("OabFe", (New-ClientProtocolMapping -FastName "OabFe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_OAB"))
$clientProtocolMappings.Add("OabBe", (New-ClientProtocolMapping -FastName "OabBe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_OAB"))
$clientProtocolMappings.Add("OwaFe", (New-ClientProtocolMapping -FastName "OwaFe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa"))
$clientProtocolMappings.Add("OwaBe", (New-ClientProtocolMapping -FastName "OwaBe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa"))
$clientProtocolMappings.Add("OwaCalFe", (New-ClientProtocolMapping -FastName "OwaCalFe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa_Calendar"))
$clientProtocolMappings.Add("OwaCalBe", (New-ClientProtocolMapping -FastName "OwaCalBe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa_Calendar"))
$clientProtocolMappings.Add("PsFe", (New-ClientProtocolMapping -FastName "PsFe" -AppPoolName "MSExchangePowerShellFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_PowerShell"))
$clientProtocolMappings.Add("PsBe", (New-ClientProtocolMapping -FastName "PsBe" -AppPoolName "MSExchangePowerShellAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_PowerShell"))
$clientProtocolMappings.Add("RestFe", (New-ClientProtocolMapping -FastName "RestFe" -AppPoolName "MSExchangeRestFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_API"))
$clientProtocolMappings.Add("RestBe", (New-ClientProtocolMapping -FastName "RestBe" -AppPoolName "MSExchangeRestAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_API"))
$clientProtocolMappings.Add("RpcFe", (New-ClientProtocolMapping -FastName "RpcFe" -AppPoolName "MSExchangeRpcProxyFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_rpc"))
$clientProtocolMappings.Add("RpcBe", (New-ClientProtocolMapping -FastName "RpcBe" -AppPoolName "MSExchangeRpcProxyAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_rpc"))
$clientProtocolMappings.Add("EwsFe", (New-ClientProtocolMapping -FastName "EwsFe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_EWS"))
$clientProtocolMappings.Add("EwsBe", (New-ClientProtocolMapping -FastName "EwsBe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_EWS"))
$clientProtocolMappings.Add("EasFe", (New-ClientProtocolMapping -FastName "EasFe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Microsoft-Server-ActiveSync"))
$clientProtocolMappings.Add("EasBe", (New-ClientProtocolMapping -FastName "EasBe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Microsoft-Server-ActiveSync"))
        
return $clientProtocolMappings
}
# End Function Get-ExchangeClientProtocolMappings


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#Function Version 1.1
#Function Version 1.1
Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteHost($WriteString)
    }
    elseif($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
# End Function Write-VerboseWriter


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
Function Import-PerformanceCounters {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$FilePaths,
[Parameter(Mandatory=$false)][Int64]$MaxSample = [Int64]::MaxValue, 
[Parameter(Mandatory=$false)][datetime]$StartTime = [datetime]::MinValue, 
[Parameter(Mandatory=$false)][datetime]$EndTime = [datetime]::MaxValue,
[Parameter(Mandatory=$false)][array]$Counters
)

#Function Version 1.6
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>
#If Load-PerformanceCounters isn't issued within the script, must use the schema from: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/AddTypeSchema/LoadPerformanceCounters_Schema.ps1
<#
    When passing something like \\*\Process(*)\* we see a dramatic decrease in performance of reading the file. In a 1 GB file we see a decrease of performance by a few minutes vs providing all the values for the counters in Process
    For example: "\\*\Process(*)\% Privileged Time","\\*\Process(*)\% Processor Time","\\*\Process(*)\% User Time","\\*\Process(*)\Creating Process ID",..... so on
#>

Function Get-FastCounterNames {
param(
[Parameter(Mandatory=$true)][string]$Path,
[Parameter(Mandatory=$true)][array]$Counters
)
    Write-VerboseWriter("Getting the Counter Names vs using wild card as this has better performance")
    [System.Collections.Generic.List[System.Object]]$masterCounterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    $findFastTrackCounters = @()
    foreach($counter in $Counters)
    {
        if(!($counter.EndsWith("\*")))
        {
            $masterCounterList.Add($counter)
        }
        else 
        {
            $findFastTrackCounters += $counter
        }
    }
    if($findFastTrackCounters -eq $null -or $findFastTrackCounters.Count -eq 0)
    {
        Write-VerboseWriter("All counters in the list are already optimized.")
        return $masterCounterList
    }
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $myParmas = @{
        Path = $Path
        StartTime = $StartTime
        EndTime = $EndTime
        MaxSample = 2
        ErrorAction = "SilentlyContinue"
        Verbose = $false 
        Counter = $findFastTrackCounters
    }
    
    $measureImport = Measure-Command {$results = (Import-Counter @myParmas).CounterSamples}
    Write-VerboseWriter("Took {0} seconds to import" -f $measureImport.TotalSeconds)

    $measureGroup = Measure-Command { $groupResults = [LoadPerformanceCounters.PerformanceCounters]::GroupPerformanceCounterSamplesByPath($results) }
    Write-VerboseWriter("Took {0} seconds to group the results" -f $measureGroup.TotalSeconds)
 
    foreach($key in $groupResults.Keys)
    {
        $inList = $false
        $counterGroup = $groupResults[$key][0]
        $counterName = $counterGroup.Path
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
        $counterNameObj = [LoadPerformanceCounters.PerformanceCounterName]::GetPerformanceCounterNameFromFullName($counterName, $counterGroup.InstanceName)
        if([string]::IsNullOrEmpty($counterNameObj.InstanceName))
        {
            $addCounter = "\\*\{0}\{1}"
        }
        else 
        {
            $addCounter = "\\*\{0}(*)\{1}"    
        }
        $addCounter = $addCounter -f $counterNameObj.ObjectName, $counterNameObj.CounterName
        $masterCounterList.Add($addCounter)
    }
    $stopWatch.Stop()
    Write-VerboseWriter("Finished getting the counter list in {0} seconds" -f $stopWatch.Elapsed.TotalSeconds)
    return $masterCounterList
}

########## Parameter Binding Exceptions ##############

foreach($filePath in $FilePaths)
{
    if(!(Test-Path $filePath))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FilePaths"
    }
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

$params = @{
    Path = $FilePaths
    StartTime = $StartTime
    EndTime = $EndTime
    MaxSample = $MaxSample
    ErrorAction = "SilentlyContinue"
    Verbose = $false 
}

if($Counters -ne $null -and $Counters.count -gt 0)
{
    $fastCounters = Get-FastCounterNames -Path ($FilePaths[0]) -Counters $Counters
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
# End Function Import-PerformanceCounters


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Load-PerformanceCounters/Load-PerformanceCounters.ps1
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

#Function Version 1.6
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
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

        public bool TryGetCounterKey(Dictionary<string,string> InputObject, string InstanceName, out string Key)
        {
            Key = string.Empty; 
            if(InputObject.ContainsKey("ObjectName") &&
                InputObject.ContainsKey("CounterName"))
            {
                string ObjectName = InputObject["ObjectName"];
                string CounterName = InputObject["CounterName"];
                if(TryGetCounterKey(ObjectName, CounterName, InstanceName, out Key))
                {
                    return true;
                }
            }
            return false; 
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

        public bool TryGetCounterKeyForThisCookedValue(double CookedValue, DateTime TimeKey, List<string> PossibleKeys, out string Key)
        {
            Key = string.Empty;
            foreach(string possibleKey in PossibleKeys)
            {
                if(this.AllCounterData[possibleKey].TimeHash[TimeKey].CookedValue == CookedValue)
                {
                    Key = possibleKey;
                    return true; 
                }
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
$measureGroupTime = Measure-Command { $hashtableGroup = [LoadPerformanceCounters.PerformanceCounters]::GroupPerformanceCounterSamplesByPath($importCounters) }
Write-VerboseWriter("[{0}]: Took {1} seconds to group the path data" -f [datetime]::Now, $measureGroupTime.TotalSeconds)
[System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
[System.Collections.Generic.Dictionary[string, LoadPerformanceCounters.CounterData]]$dictionaryAllCounterData = New-Object 'System.Collections.Generic.Dictionary[string, LoadPerformanceCounters.CounterData]'
[System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]]]$hashtableCounterObjectGrouping = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]]'
$monitor = New-Object PSCustomObject
$monitor | Add-Member -MemberType NoteProperty -Name "TimeHashCount" -Value 0
$monitor | Add-Member -MemberType NoteProperty -Name "Key" -Value ([string]::Empty)
$monitor | Add-Member -MemberType NoteProperty -Name "ContainsMinValue" -Value $false
$monitor | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ([string]::Empty)

#TODO: Add multi threading here.
foreach($key in $hashtableGroup.Keys)
{
    $counterObj =  New-Object LoadPerformanceCounters.CounterData([LoadPerformanceCounters.PerformanceCounterName]::GetPerformanceCounterNameFromFullName($hashtableGroup[$key][0].Path, $hashtableGroup[$key][0].InstanceName), $hashtableGroup[$key])
    $dictionaryAllCounterData.Add($key, $counterObj)
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
        $hashtableCounterObjectGrouping.Add($counterObj.ObjectName.ToLower(), (New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'))
    }
    if(!($hashtableCounterObjectGrouping[$counterObj.ObjectName].ContainsKey($counterObj.CounterName)))
    {
        $hashtableCounterObjectGrouping[$counterObj.ObjectName].Add($counterObj.CounterName.ToLower(),(New-Object System.Collections.Generic.List[string]))
    }
    $hashtableCounterObjectGrouping[$counterObj.ObjectName][$counterObj.CounterName].Add($key)
    if($counterObj.TimeHash.Count -gt $monitor.TimeHashCount -or
        ($monitor.Key -eq [string]::Empty -or 
        $monitor.ContainsMinValue))
    {
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
# End Function Load-PerformanceCounters
Add-Type @"
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace PerformanceDataClientProtocolAnalyzer
{
    public enum ClientProtocolType
    {
        AutoDFe,
        AutoDBe,
        EasFe,
        EasBe,
        EcpFe,
        EcpBe,
        EwsFe,
        EwsBe,
        MapiAddBook,
        MapiFe,
        MapiBe,
        OabFe,
        OabBe,
        OwaFe,
        OwaBe,
        OwaCalFe,
        OwaCalBe,
        PsFe,
        PsBe,
        RestFe,
        RestBe,
        RpcFe,
        RpcBe
    }

    public class DisplayMainProtocolsViewer
    {
        private ClientProtocolAnalyzer data; 
        public string DateTime {get {return this.data.DateTime;}}
        public double CpuTotal {get {return Math.Round(this.data.ProcessorTimeTotal, 2);}}
        public double ContextSwitches {get {return Math.Round(this.data.ContextSwitches, 2);}}
        public double PQL {get {return Math.Round(this.data.ProcessorQueueLength,2);}}
        public double MapiFeRE {get {return Math.Round(this.data.ClientProtocol["MapiFe"].RequestsExecuting, 2);}}
        public double MapiFeSLDP {get {return Math.Round(this.data.ClientProtocol["MapiFe"].RequestsExecutedSinceLastDataPoint, 2);}}
        public double MapiFeCR {get {return Math.Round(this.data.ClientProtocol["MapiFe"].ContentionRate, 2);}}
        public double MapiFeTGc {get {return Math.Round(this.data.ClientProtocol["MapiFe"].TimeInGc, 2);}}
        public double MapiFePT {get {return Math.Round(this.data.ClientProtocol["MapiFe"].ProcessProcessorTime, 2);}}
        public double MapiBeRE {get {return Math.Round(this.data.ClientProtocol["MapiBe"].RequestsExecuting, 2);}}
        public double MapiBeSLDP {get {return Math.Round(this.data.ClientProtocol["MapiBe"].RequestsExecutedSinceLastDataPoint, 2);}}
        public double MapiBeCR {get {return Math.Round(this.data.ClientProtocol["MapiBe"].ContentionRate, 2);}}
        public double MapiBeTGc {get {return Math.Round(this.data.ClientProtocol["MapiBe"].TimeInGc, 2);}}
        public double MapiBePT {get {return Math.Round(this.data.ClientProtocol["MapiBe"].ProcessProcessorTime, 2);}}
        public double RpcFeRE {get {return Math.Round(this.data.ClientProtocol["RpcFe"].RequestsExecuting, 2);}}
        public double RpcFeSLDP {get {return Math.Round(this.data.ClientProtocol["RpcFe"].RequestsExecutedSinceLastDataPoint, 2);}}
        public double RpcFeCR {get {return Math.Round(this.data.ClientProtocol["RpcFe"].ContentionRate, 2);}}
        public double RpcFeTGc {get {return Math.Round(this.data.ClientProtocol["RpcFe"].TimeInGc, 2);}}
        public double RpcFePT {get {return Math.Round(this.data.ClientProtocol["RpcFe"].ProcessProcessorTime, 2);}}
        public double RpcBeRE {get {return Math.Round(this.data.ClientProtocol["RpcBe"].RequestsExecuting, 2);}}
        public double RpcBeSLDP {get {return Math.Round(this.data.ClientProtocol["RpcBe"].RequestsExecutedSinceLastDataPoint, 2);}}
        public double RpcBeCR {get {return Math.Round(this.data.ClientProtocol["RpcBe"].ContentionRate, 2);}}
        public double RpcBeTGc {get {return Math.Round(this.data.ClientProtocol["RpcBe"].TimeInGc, 2);}}
        public double RpcBePT {get {return Math.Round(this.data.ClientProtocol["RpcBe"].ProcessProcessorTime, 2);}}

        public DisplayMainProtocolsViewer(ClientProtocolAnalyzer Data)
        {
            this.data = Data;
        }
    }
    public class ClientProtocolBreakDown
    {
        public double ProcessProcessorTime;
        public double RequestsExecuting;
        public double RequestsTotal;
        public double RequestsExecutedSinceLastDataPoint;
        public double TimeInGc;
        public double ContentionRate;
        public double Id; 
    }

    public class ClientProtocolAnalyzer
    {
        public string DateTime;
        public double ProcessorTimeTotal;
        public double ContextSwitches;
        public double ProcessorQueueLength;
        public Dictionary<string, ClientProtocolBreakDown> ClientProtocol;
        public DisplayMainProtocolsViewer DisplayView;

        public ClientProtocolAnalyzer()
        {
            this.DisplayView = new DisplayMainProtocolsViewer(this);
            this.ClientProtocol = new  Dictionary<string, ClientProtocolBreakDown>();
            List<ClientProtocolType> clientProtocolTypeList = (Enum.GetValues(typeof(ClientProtocolType)).Cast<ClientProtocolType>().ToList());
            foreach(int clientProtocolType in clientProtocolTypeList)
            {
                this.ClientProtocol.Add((Enum.GetName(typeof(ClientProtocolType), clientProtocolType)), new ClientProtocolBreakDown());
            }
        }
    }
}

"@

Function Main {

    if($Directory -ne [string]::Empty)
    {
        
        $filePaths = (Get-ChildItem $Directory | ?{$_.Extension -eq ".blg"}).VersionInfo.FileName
    }
    else 
    {
        [array]$filePaths = $FilePath 
    }
    foreach($file in $filePaths)
    {
        if(!(Test-Path $file))
        {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid files"
        }
    }

    $loadedData = Load-PerformanceCounters -FilePaths $filePaths -Counters $counters

    $clientProtocolMappings = Get-ExchangeClientProtocolMappings
    $w3svcActiveRequestKeyList = New-Object 'System.Collections.Generic.List[string]'
    #possible w3wp.exe processes 
    if($loadedData.TryGetCounterInstanceKeys("w3svc_w3wp", "active requests", [ref]$w3svcActiveRequestKeyList))
    {
        foreach($key in $clientProtocolMappings.Keys)
        {
            $possible = $w3svcActiveRequestKeyList | ?{$_ -like ("*{0}*" -f $clientProtocolMappings[$key].AppPoolName)}
            foreach($pidKey in $possible)
            {
                $startIndex = $pidKey.IndexOf("(",2)
                $endIndex = $pidKey.IndexOf("_", $startIndex)
                $clientProtocolMappings[$key].PossiblePIDs.Add($pidKey.Substring($startIndex + 1, $endIndex - $startIndex -1))
            }
        }
    }

    $processIdKeys = New-Object 'System.Collections.Generic.List[string]'
    if($loadedData.TryGetCounterInstanceKeys("Process","ID Process", [ref]$processIdKeys))
    {
        [System.Collections.Generic.List[string]]$w3wpProcessIdKeys = $processIdKeys | ?{$_ -like "*(w3wp*"}
    }
    $netProcessIdKeys = New-Object 'System.Collections.Generic.List[string]'
    if($loadedData.TryGetCounterInstanceKeys(".NET CLR Memory","Process ID", [ref]$netProcessIdKeys))
    {
        [System.Collections.Generic.List[string]]$w3wpNetProcessIdKeys = $netProcessIdKeys | ?{$_ -like "*(w3wp*"}
    }

    $aspNetRequestsExecutingDictionary = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $aspNetRequestsExecutingDictionary.Add("ObjectName","ASP.NET Applications")
    $aspNetRequestsExecutingDictionary.Add("CounterName","Requests Executing")

    $aspNetRequestsTotalDictionary = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $aspNetRequestsTotalDictionary.Add("ObjectName","ASP.NET Applications")
    $aspNetRequestsTotalDictionary.Add("CounterName","Requests Total")

    $timeIndex = 0
    [System.Collections.Generic.List[System.Object]]$analyzedResults = New-Object -TypeName System.Collections.Generic.List[System.Object]
    while($timeIndex -lt $loadedData.GetTimeKeys.Count)
    {
        $counterKey = [string]::Empty
        $keyList = New-Object 'System.Collections.Generic.List[string]'
        $timeKey = $loadedData.GetTimeKeys[$timeIndex]
        $clpAnalyzer = New-Object PerformanceDataClientProtocolAnalyzer.ClientProtocolAnalyzer
        $clpAnalyzer.DateTime = $loadedData.GetTimeKeys[$timeIndex]
        if($loadedData.TryGetCounterKey("Processor","% Processor Time", "_Total", [ref]$counterKey))
        {
            $clpAnalyzer.ProcessorTimeTotal = $loadedData.AllCounterData[$counterKey].TimeHash[$timeKey].CookedValue
        }
        if($loadedData.TryGetCounterKey("System","Processor Queue Length", [ref] $counterKey))
        {
            $clpAnalyzer.ProcessorQueueLength = $loadedData.AllCounterData[$counterKey].TimeHash[$timeKey].CookedValue
        }
        if($loadedData.TryGetCounterKey("System", "Context Switches/sec", [ref]$counterKey))
        {
            $clpAnalyzer.ContextSwitches = $loadedData.AllCounterData[$counterKey].TimeHash[$timeKey].CookedValue
        }
        foreach($protocolKey in $clientProtocolMappings.Keys)
        {
            $skipProcess = $false 
            $skipNet = $false 
            if($loadedData.TryGetCounterKey($aspNetRequestsExecutingDictionary, $clientProtocolMappings[$protocolKey].AspCounterName, [ref] $counterKey))
            {
                $clpAnalyzer.ClientProtocol.$protocolKey.RequestsExecuting = $loadedData.AllCounterData[$counterKey].TimeHash[$timeKey].CookedValue
            }
            if($loadedData.TryGetCounterKey($aspNetRequestsTotalDictionary, $clientProtocolMappings[$protocolKey].AspCounterName, [ref]$counterKey))
            {
                $clpAnalyzer.ClientProtocol.$protocolKey.RequestsTotal = $loadedData.AllCounterData[$counterKey].TimeHash[$timeKey].CookedValue
                if($timeIndex -ne 0)
                {
                    $clpAnalyzer.ClientProtocol.$protocolKey.RequestsExecutedSinceLastDataPoint = $clpAnalyzer.ClientProtocol.$protocolKey.RequestsTotal - $loadedData.AllCounterData[$counterKey].TimeHash[$loadedData.GetTimeKeys[$timeIndex - 1]].CookedValue
                }
            }
            if($clientProtocolMappings[$protocolKey].ProcessKey -eq [string]::Empty -or 
            $clientProtocolMappings[$protocolKey].CurrentPid -ne $loadedData.AllCounterData[$clientProtocolMappings[$protocolKey].ProcessKey].TimeHash[$timeKey].CookedValue)
            {
                $foundKey = $false 
                $clientProtocolMappings[$protocolKey].ProcessKey = [string]::Empty
                foreach($pPIds in $clientProtocolMappings[$protocolKey].PossiblePIDs)
                {
                    foreach($possibleKey in $w3wpProcessIdKeys)
                    {
                        if($pPIds -eq $loadedData.AllCounterData[$possibleKey].TimeHash[$timeKey].CookedValue)
                        {
                            $foundKey = $true 
                            $clientProtocolMappings[$protocolKey].ProcessKey = $possibleKey
                            break 
                        }
                    }
                    if($foundKey){break}
                }
            }
            if($clientProtocolMappings[$protocolKey].ProcessKey -eq [string]::Empty)
            {
                #No current running process for this app pool 
                $clpAnalyzer.ClientProtocol.$protocolKey.ProcessProcessorTime = -1
                $clpAnalyzer.ClientProtocol.$protocolKey.TimeInGc = -1 
                $clpAnalyzer.ClientProtocol.$protocolKey.ContentionRate = -1 
                $clpAnalyzer.ClientProtocol.$protocolKey.Id = -1 
            }
            else 
            {
                $clpAnalyzer.ClientProtocol.$protocolKey.Id = $loadedData.AllCounterData[$clientProtocolMappings[$protocolKey].ProcessKey].TimeHash[$timeKey].CookedValue
                $clpAnalyzer.ClientProtocol.$protocolKey.ProcessProcessorTime = $loadedData.AllCounterData[($clientProtocolMappings[$protocolKey].ProcessKey).Replace("id process","% processor time")].TimeHash[$timeKey].CookedValue
                if($clientProtocolMappings[$protocolKey].NETKey -eq [string]::Empty -or 
                    $clientProtocolMappings[$protocolKey].CurrentPid -ne $loadedData.AllCounterData[$clientProtocolMappings[$protocolKey].NETKey].TimeHash[$timeKey].CookedValue)
                {
                    $foundKey = $false 
                    $clientProtocolMappings[$protocolKey].NETKey = [string]::Empty
                    foreach($pPIds in $clientProtocolMappings[$protocolKey].PossiblePIDs)
                    {
                        foreach($possibleKey in $w3wpNetProcessIdKeys)
                        {
                            if($pPIds -eq $loadedData.AllCounterData[$possibleKey].TimeHash[$timeKey].CookedValue)
                            {
                                $foundKey = $true 
                                $clientProtocolMappings[$protocolKey].NETKey = $possibleKey
                                break 
                            }
                        }
                        if($foundKey){break}
                    }
                }
                if($clientProtocolMappings[$protocolKey].NETKey -eq [string]::Empty)
                {
                    $clpAnalyzer.ClientProtocol.$protocolKey.TimeInGc = -1 
                    $clpAnalyzer.ClientProtocol.$protocolKey.ContentionRate = -1 
                }
                else 
                {
                    $clpAnalyzer.ClientProtocol.$protocolKey.TimeInGc = $loadedData.AllCounterData[($clientProtocolMappings[$protocolKey].NETKey).Replace("process id","% time in gc")].TimeHash[$timeKey].CookedValue
                    $clpAnalyzer.ClientProtocol.$protocolKey.ContentionRate = $loadedData.AllCounterData[(($clientProtocolMappings[$protocolKey].NETKey).Replace(".net clr memory",".net clr locksandthreads")).Replace("process id","contention rate / sec")].TimeHash[$timeKey].CookedValue
                }
            }
        }   

        $timeIndex++
        $analyzedResults.Add($clpAnalyzer)
    }

    $saveToDirectory = [System.IO.Directory]::GetParent($filePaths[0])
    $fileInfo = [System.IO.FileInfo]::new($filePaths[0])
    $analyzedResults.DisplayView | Format-Table * -AutoSize | Out-File ($output = "{0}\{1}_{2}_{3}.txt" -f $saveToDirectory.FullName,$fileInfo.BaseName,$scriptName,(Get-Date).ToString("yyyyMMddHHMM"))
    Write-Host("Output: {0}" -f $output)
    $analyzedResults | Export-Clixml -Depth 15 -Path ($output.Replace(".txt",".xml")) -Encoding UTF8
    $Global:debugResults = $analyzedResults
    $Global:debugImportData = $loadedData
}

Main 
