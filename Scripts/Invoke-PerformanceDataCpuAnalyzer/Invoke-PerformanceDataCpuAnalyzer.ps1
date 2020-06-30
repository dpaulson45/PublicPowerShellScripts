[CmdletBinding()]
param(
[Parameter(Mandatory=$true,ParameterSetName="Directory")][string]$Directory,
[Parameter(Mandatory=$true,ParameterSetName="FilePath")][string]$FilePath,
[Parameter(Mandatory=$false)][switch]$MapiConnectionBreakDown
)

$counters = "\\*\Process(*)\% Processor Time","\\*\Processor(*)\% Processor Time","\\*\Process(*)\% Privileged Time","\\*\Processor(*)\% Privileged Time","\\*\System\Processor Queue Length","\\*\System\Context Switches/sec","\\*\Process(*)\ID Process"
$exchangeContainsProcesses = @("Microsoft","w3wp","MSExchange","ForeFrontActiveDirectoryConnector","UmService","UmWorkerProcess","EdgeTransport","ScanningProcess","(fms)","ParserServer","ComplianceAuditService","hostcontrollerservice","sfTracing","noderunner").ToLower()
$storeWorker = "microsoft.exchange.store.worker"
$windowsContainsProcesses = @("clussvc","conHost","csrss","dwm","explorer","inetinfo","logonUI","lsass","mmc","mqsvc","msdtc","rdpclip","relog","rhs","rundll32","RuntimeBroker","SearchUI","Services","sftracing","ShellExperienceHost","sihost","smss","SMSvcHost","spoolsv","svchost","System","taskhostw","Taskmgr","UpdateService","winlogon","WmiApSrv","WMSvc").ToLower()
$scriptName = "PerformanceDataCpuAnalyzer"

if($MapiConnectionBreakDown)
{
    $mapiConnectionBreakDownCounters = @("\\*\.NET CLR LocksAndThreads(*)\Contention Rate / Sec",
    "\\*\.NET CLR Memory(*)\% Time in GC",
    "\\*\.NET CLR Memory(*)\Process ID",
    "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_mapi)\Requests Executing",
    "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_mapi_emsmdb)\Requests Executing",
    "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_mapi_emsmdb)\Requests Total",
    "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_mapi)\Requests Total",
    "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_rpc)\Requests Executing",
    "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_rpc)\Requests Executing",
    "\\*\MSExchange MapiHttp Emsmdb\User Count",
    "\\*\MSExchange MapiHttp Emsmdb\Dispatch task threads",
    "\\*\MSExchange MapiHttp Emsmdb\Connection Count",
    "\\*\MSExchange MapiHttp Emsmdb\Averaged Latency",
    "\\*\MSExchange MapiHttp Emsmdb\Dispatch task operations/sec",
    "\\*\MSExchange MapiHttp Emsmdb\Dispatch task queue length",
    "\\*\MSExchange MapiHttp Emsmdb\Dispatch task active threads",
    "\\*\MSExchange MapiHttp Emsmdb\Packets/sec",
    "\\*\MSExchange MapiHttp Emsmdb\Requests",
    "\\*\MSExchange MapiHttp Emsmdb\Operations/sec",
    "\\*\W3SVC_W3WP(*)\Active Requests",
    "\\*\W3SVC_W3WP(*)\Active Threads Count",
    "\\*\W3SVC_W3WP(*)\Requests / Sec")
    $counters += $mapiConnectionBreakDownCounters
}

#############################
#
# Template Functions 
#
#############################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Group-ObjectHashTable/Group-ObjectHashTable.ps1
Function Group-ObjectHashTable {
param
(
  [string[]]
  $Property
)
#Function Version 1.0
#Found from: http://powershell.one/tricks/performance/group-object
begin
{
  # create an empty hashtable
  $hashtable = @{}
}

process
{
    # create a key based on the submitted properties, and turn
    # it into a string
  $key = $(foreach($prop in $Property) { $_.$prop }) -join ','
      
  # check to see if the key is present already
  if ($hashtable.ContainsKey($key) -eq $false)
  {
    # add an empty array list 
    $hashtable[$key] = [Collections.Arraylist]@()
  }

  # add element to appropriate array list:
  $null = $hashtable[$key].Add($_)
}

end
{
  # return the entire hashtable:
  $hashtable
}

}
# End Function Group-ObjectHashTable


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
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


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-CounterDataObject/New-CounterDataObject.ps1
Function New-CounterDataObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$PerformanceCounterSamples
)

#Function Version 1.2
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
#>

Add-Type @"
using System; 
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace PerformanceCounters
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
    }

    public class CounterData : PerformanceCounterName
    {
        public CounterAccuracy Accuracy; 
        public object[] AllData; 
        public int GetDataCount { get { return AllData.Count() - 1;  } }
        public Hashtable TimeHash; 
        public IEnumerable<object> GetData { get {return AllData.Skip(1); } }
        public object FirstSample {get {return GetData.First(); } }
        public object LastSample {get {return GetData.Last(); } }

        public CounterData()
        {
            this.Accuracy = new CounterAccuracy();
            this.TimeHash = new Hashtable();
        }
    }
}


"@

Function Get-CounterDataObject {
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)
    $counterDataObj = New-Object PerformanceCounters.CounterData
    $counterNameObj = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $PerformanceCounterSample
    $counterDataObj.FullName = $counterNameObj.FullName
    $counterDataObj.ServerName = $counterNameObj.ServerName
    $counterDataObj.ObjectName = $counterNameObj.ObjectName
    $counterDataObj.InstanceName = $counterNameObj.InstanceName
    $counterDataObj.CounterName = $counterNameObj.CounterName
    return $counterDataObj
}

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

$counterObj = Get-CounterDataObject -PerformanceCounterSample $PerformanceCounterSamples[0]
$counterObj.AllData = $PerformanceCounterSamples
foreach($datapoint in $counterObj.GetData)
{
    try
    {
        $counterObj.TimeHash.Add($datapoint.TimeStamp, $datapoint)
    }
    catch 
    {
        #Do nothing, it appears that this sometimes happens, likely due to multiple files in the load
        #Might need to look into some debug logging to determine if this is going to be an issue or not 
    }
}

return $counterObj
}
# End Function New-CounterDataObject


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
# End Function Load-PerformanceCounters


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
Function Get-CounterSampleToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)

#Function Version 1.2

$counterObj = New-Object -TypeName pscustomobject
$FullName = $PerformanceCounterSample.Path 
#\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
$endOfServerIndex = $FullName.IndexOf("\",2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
$startOfCounterIndex = $FullName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
$endOfCounterObjectIndex = $FullName.IndexOf("(") 
if($endOfCounterObjectIndex -eq -1){$endOfCounterObjectIndex = $startOfCounterIndex - 1}
if(($FullName.Contains("(")) -and ($FullName.Contains("#")))
{
    $instanceName = ($FullName.Substring($endOfCounterObjectIndex + 1, ($FullName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
}
else 
{
    $instanceName = ($PerformanceCounterSample.InstanceName)
}
$counterObj | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullName
$counterObj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullName.Substring(2,($endOfServerIndex - 2)))
$counterObj | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObj | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
$counterObj | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullName.Substring($startOfCounterIndex))

return $counterObj
}
# End Function Get-CounterSampleToCounterObjectName


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

#Function Version 1.5
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
#>
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

    $measureGroup = Measure-Command { $groupResults = $results | Group-Object Path }
    Write-VerboseWriter("Took {0} seconds to group the results" -f $measureGroup.TotalSeconds)
 
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
Add-Type @"
using System; 
using System.Collections;
using System.Collections.Generic;

namespace PerformanceDataCpuAnalyzer
{

public class ProcessesBreakDown
{
	public double ProcessorTimeSum;
	public double ProcessorTimeCpuUsage;
	public double PrivilegedTimeSum;
	public double PrivilegedTimeCpuUsage;
}

public class CpuDisplayView
{
	private CpuDataBreakDown Data;
	public string DateTime {get {return this.Data.DateTime;} }
	public double PQL {get {return Math.Round(this.Data.ProcessorQueueLength, 2);} }
	public double ContextSwitches { get {return Math.Round(this.Data.ContextSwitches, 2);} }
	public double TotalCpuUsage {get {return Math.Round(this.Data.TotalCpuUsage, 2); } }
	public double UserCpuUsage {get {return Math.Round(this.Data.UserTimeCpuUsage, 2);} }
	public double PrivCpuUsage {get {return Math.Round(this.Data.PrivilegedTimeCpuUsage, 2); } }
	public double ExCpuUsage {get {return Math.Round(this.Data.Exchange.ProcessorTimeCpuUsage, 2); } }
	public double SwCpuUsage { get { return Math.Round(this.Data.StoreWorker.ProcessorTimeCpuUsage, 2);} }
	public double WinCpuUsage {get {return Math.Round(this.Data.Windows.ProcessorTimeCpuUsage, 2); } }
	public double TpCpuUsage {get {return Math.Round(this.Data.ThirdParty.ProcessorTimeCpuUsage, 2); } }
	public string HighProcess1 {get; set;}
	public string HighProcess2 {get; set;}
	public string HighProcess3 {get; set;}
	
	public CpuDisplayView(CpuDataBreakDown data)
	{
		this.Data = data;
	}
}

public class CpuDataBreakDown 
{
	public string DateTime; 
	public double ProcessorTimeSum;
	public double ProcessorTimeTotal;
	public double UserTimeCpuUsage;
	public double PrivilegedTimeSum;
	public double PrivilegedTimeTotal;
	public double PrivilegedTimeCpuUsage;
	public double ProcessIdleTime;
	public ProcessesBreakDown Exchange;
	public ProcessesBreakDown Windows;
	public ProcessesBreakDown ThirdParty;
	public ProcessesBreakDown StoreWorker;
	public double CpuBusyTime; 
	public double TotalCpuUsage; 
	public double ContextSwitches;
	public double ProcessorQueueLength; 
	public List<object> DataPointsProcessorTime;
	public List<object> DataPointsPrivilegedTime;
	public CpuDisplayView DisplayView;
	
	public CpuDataBreakDown()
	{
		this.DataPointsProcessorTime = new List<object>();
		this.DataPointsPrivilegedTime = new List<object>();
		this.Exchange = new ProcessesBreakDown();
		this.Windows = new ProcessesBreakDown();
		this.ThirdParty = new ProcessesBreakDown();
		this.StoreWorker = new ProcessesBreakDown();
		this.DisplayView = new CpuDisplayView(this);
	}
}

public class CpuMapiConnectionDisplayView
{
    private CpuMapiConnectionBreakdown Data;
    public string DateTime {get {return this.Data.DateTime;}}
    public double CpuTotal {get {return Math.Round(this.Data.TotalCpuUsage, 2);}}
    public double ContextSwitches {get {return Math.Round(this.Data.ContextSwitches, 2); }}
    public double PQL {get {return Math.Round(this.Data.ProcessorQueueLength, 2);}}
    public double MapiFeRE {get {return Math.Round(this.Data.AspNetMapiFeRequestsExecuting, 2);}}
    public double MapiFeRT {get {return Math.Round(this.Data.AspNetMapiFeRequestsTotal, 2);}}
    public double MapiFeRSLDP {get {return Math.Round(this.Data.AspNetMapiFeRequestsExecutedSinceLastDataPoint, 2);}}
    public double MapiBeRE {get {return Math.Round(this.Data.AspNetMapiBeRequestsExecuting, 2);}}
    public double MapiBeRT {get {return Math.Round(this.Data.AspNetMapiBeRequestsTotal, 2);}}
    public double MapiBeRSLDP {get {return Math.Round(this.Data.AspNetMapiBeRequestsExecutedSinceLastDataPoint, 2);}}
    public double RpcFeRE {get {return Math.Round(this.Data.AspNetRpcFeRequestsExecuting, 2);}}
    public double RpcBeRE {get {return Math.Round(this.Data.AspNetRpcBeRequestsExecuting, 2);}}
    public double UserCount {get {return Math.Round(this.Data.MapiMailboxUserCount,2);}}
    public double ConnectCount {get {return Math.Round(this.Data.MapiMailboxConnectionCount, 2);}}
    public double AvgLatency {get {return Math.Round(this.Data.MapiMailboxAverageLatency, 2);}}
    public double DisTskThreads {get {return Math.Round(this.Data.MapiMailboxDispatchTaskThreads, 2);}}
    public double DisTskOp {get {return Math.Round(this.Data.MapiMailboxDispatchTaskOperations, 2);}}
    public double DisTskQL {get {return Math.Round(this.Data.MapiMailboxDispatchTaskQueueLength, 2); }}
    public double DisTsActThreads {get {return Math.Round(this.Data.MapiMailboxDispatchTaskActiveThreads, 2);}}
    public double MapiPackets {get {return Math.Round(this.Data.MapiMailboxPackets, 2);}}
    public double MapiRequests {get {return Math.Round(this.Data.MapiMailboxRequests, 2); }}
    public double MapiOp {get {return Math.Round(this.Data.MapiMailboxOperations,2); }}
    //public double W3wpAR {get {return Math.Round(this.Data.W3wpActiveRequests, 2);}}
    //public double W3wpATC {get {return Math.Round(this.Data.W3wpActiveThreadsCount, 2); }}
    //public double W3wpRequest {get {return Math.Round(this.Data.W3wpRequest, 2); }}
    public double MapiLockConRate {get {return Math.Round(this.Data.MapiMailboxContentionRate, 4); }}
    public double MapiGcTime {get {return Math.Round(this.Data.MapiMailboxTimeInGC, 2);}}
    public double MapiProcessTime {get {return Math.Round(this.Data.MapiProcessProcessorTime, 2); }}

    public CpuMapiConnectionDisplayView(CpuMapiConnectionBreakdown data)
    {
        this.Data = data;
    }
}

public class CpuMapiConnectionBreakdown
{
    public string DateTime; 
    public double TotalCpuUsage;
    public double ContextSwitches;
    public double ProcessorQueueLength;
    public double MapiProcessProcessorTime;
    public double MapiMailboxContentionRate;
    public double MapiMailboxTimeInGC;
    public string MapiNetProcessInstanceKey;
    public double MapiProcessId;
    public double AspNetMapiFeRequestsExecuting; 
    public double AspNetMapiBeRequestsExecuting;
    public double AspNetMapiFeRequestsTotal;
    public double AspNetMapiBeRequestsTotal;
    public double AspNetMapiFeRequestsExecutedSinceLastDataPoint;
    public double AspNetMapiBeRequestsExecutedSinceLastDataPoint;
    public double AspNetRpcFeRequestsExecuting;
    public double AspNetRpcBeRequestsExecuting;
    public double MapiMailboxUserCount;
    public double MapiMailboxConnectionCount;
    public double MapiMailboxAverageLatency;
    public double MapiMailboxDispatchTaskThreads;
    public double MapiMailboxDispatchTaskOperations;
    public double MapiMailboxDispatchTaskQueueLength;
    public double MapiMailboxDispatchTaskActiveThreads;
    public double MapiMailboxPackets;
    public double MapiMailboxRequests;
    public double MapiMailboxOperations;
    public double W3wpActiveRequests;
    public double W3wpActiveThreadsCount;
    public double W3wpRequest;
    public List<object> NetLockAndContentionDataPoints;
    public List<object> NetClrMemoryTimeInGcDataPoints;
    public List<object> NetClrMemoryProcessIdDataPoints;
    public List<object> W3wpActiveRequestsDataPoints;
    public List<object> W3wpActiveThreadsCountDataPoints; 
    public List<object> W3wpRequestsDataPoints;
    public List<object> AllDataPoints;
    public CpuMapiConnectionDisplayView DisplayView;

    public CpuMapiConnectionBreakdown()
    {
        this.NetLockAndContentionDataPoints = new List<object>();
        this.NetClrMemoryTimeInGcDataPoints = new List<object>();
        this.NetClrMemoryProcessIdDataPoints = new List<object>();
        this.W3wpActiveRequestsDataPoints = new List<object>();
        this.W3wpActiveThreadsCountDataPoints = new List<object>();
        this.W3wpRequestsDataPoints = new List<object>();
        this.AllDataPoints = new List<object>();
        this.DisplayView = new CpuMapiConnectionDisplayView(this);
    }
}

}
"@

Function Get-W3svcW3wpProcessIdFromString{
param(
[Parameter(Mandatory=$true)][string]$CounterString
)
    $startIndex = $CounterString.IndexOf("(", 2)
    $endIndex = $CounterString.IndexOf("_",$startIndex)
    $returnValue = $CounterString.Substring($startIndex + 1, $endIndex - $startIndex - 1)
    return $returnValue
}

Function Get-KeyIdProcessForThisId{
param(
[Parameter(Mandatory=$true)][double]$Id,
[Parameter(Mandatory=$true)][array]$PossibleKeys,
[Parameter(Mandatory=$true)][object]$TimeKey,
[Parameter(Mandatory=$true)][hashtable]$Data
)
    $returnKey = $null
    foreach($key in $PossibleKeys)
    {
        if($Data[$key].TimeHash[$TimeKey].CookedValue -eq $Id)
        {
            $returnKey = $key
            break 
        }
    }
    return $returnKey
}

Function Invoke-CpuMapiConnectionBreakDownAnalyzer {

    $netLocksAndThreadsKeyInstances = @()
    $netClrMemoryTimeInGcKeyInstances = @()
    $netClrMemoryProcessIdKeyInstances = @()
    $w3wpActiveRequestsKeyInstances = @()
    $w3wpActiveThreadsCountKeyInstances = @()
    $w3wpRequestsKeyInstances = @()
    foreach($key in $mapiConnectionCounterKeys)
    {
        if($key -like "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_mapi)\Requests Executing")
        {
            $aspNetMapiFeRequestsExeKey = $key 
        }
        elseif($key -like "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_mapi_emsmdb)\Requests Executing")
        {
            $aspNetMapiBeRequestsExeKey = $key 
        }
        elseif($key -like "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_mapi_emsmdb)\Requests Total")
        {
            $aspNetMapiBeRequestsTotalKey = $key 
        }
        elseif($key -like "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_mapi)\Requests Total")
        {
            $aspNetMapiFeRequestsTotalKey = $key
        }
        elseif($key -like "\\*\ASP.NET Applications(_LM_W3SVC_1_ROOT_rpc)\Requests Executing")
        {
            $aspNetRpcFeRequestsExeKey = $key 
        }
        elseif($key -like "\\*\ASP.NET Applications(_LM_W3SVC_2_ROOT_rpc)\Requests Executing")
        {
            $aspNetRpcBeRequestsExeKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\User Count")
        {
            $mapiMailboxUserCountKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Dispatch task threads")
        {
            $mapiMailboxDisTaskThreadsKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Connection Count")
        {
            $mapiMailboxConnectionCountKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Averaged Latency")
        {
            $mapiMailboxAveragedLatencyKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Dispatch task operations/sec")
        {
            $mapiMailboxDisTaskOperationsKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Dispatch task queue length")
        {
            $mapiMailboxDisTaskQueueLengthKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Dispatch task active threads")
        {
            $mapiMailboxDisTaskActiveThreadsKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Packets/sec")
        {
            $mapiMailboxPacketsKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Requests")
        {
            $mapiMailboxRequestsKey = $key 
        }
        elseif($key -like "\\*\MSExchange MapiHttp Emsmdb\Operations/sec")
        {
            $mapiMailboxOperationsKey = $key 
        }
        elseif($key -like "\\*\.NET CLR LocksAndThreads(*)\Contention Rate / Sec")
        {
            $netLocksAndThreadsKeyInstances += $key 
        }
        elseif($key -like "\\*\.NET CLR Memory(*)\% Time in GC")
        {
            $netClrMemoryTimeInGcKeyInstances += $key 
        }
        elseif($key -like "\\*\.NET CLR Memory(*)\Process ID")
        {
            $netClrMemoryProcessIdKeyInstances += $key 
        }
        elseif($key -like "\\*\W3SVC_W3WP(*)\Active Requests")
        {
            $w3wpActiveRequestsKeyInstances += $key 
        }
        elseif($key -like "\\*\W3SVC_W3WP(*)\Active Threads Count")
        {
            $w3wpActiveThreadsCountKeyInstances += $key 
        }
        elseif($key -like "\\*\W3SVC_W3WP(*)\Requests / Sec")
        {
            $w3wpRequestsKeyInstances += $key 
        }
    }
    $mapiMailboxKeys = @()
    $mapiProxyKeys = @()
    foreach($key in $w3wpRequestsKeyInstances)
    {
        if($key.Contains("_msexchangemapimailboxapppool)"))
        {
            $mapiMailboxKeys += $key
        }
        elseif($key.Contains("_msexchangemapifrontendapppool)"))
        {
            $mapiProxyKeys += $key
        }
    }
    $multipleMapiMailboxProcessIds = $false 
    $multipleMapiProxyProcessIds = $false 
    if($mapiMailboxKeys.Count -gt 1)
    {
        $multipleMapiMailboxProcessIds = $true
    } else { [double]$mapiMailboxWebAppProcessId = Get-W3svcW3wpProcessIdFromString -CounterString $mapiMailboxKeys[0] }
    if($mapiProxyKeys.Count -gt 1)
    {
        $multipleMapiProxyProcessIds = $true 
    } else { [double]$mapiProxyWebAppProcessId = Get-W3svcW3wpProcessIdFromString -CounterString $mapiProxyKeys[0] }

    $currentPossibleMapiMailboxProcessIdObject = $null
    $currentPossibleMapiProxyProcessIdObject = $null
    $currentPossibleNetMapiMailboxProcessIdObject = $null
    $currentPossibleNetMapiProxyProcessIdObject = $null

    [System.Collections.Generic.List[System.Object]]$analyzedResults = New-Object -TypeName System.Collections.Generic.List[System.Object]
    $timeIndex = 0
    while($timeIndex -lt $timeKeys.Count)
    {
        $timeDataPointKey = $timeKeys[$timeIndex]
        $cpuMapiConnectionBreakdownResults = New-Object PerformanceDataCpuAnalyzer.CpuMapiConnectionBreakdown
        $cpuMapiConnectionBreakdownResults.DateTime = $timeDataPointKey.ToString()
        $cpuMapiConnectionBreakdownResults.TotalCpuUsage = $loadedData[$cpuTotalKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.ContextSwitches = $loadedData[$contextSwitchesKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.ProcessorQueueLength = $loadedData[$processorQueueLengthKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetMapiFeRequestsExecuting = $loadedData[$aspNetMapiFeRequestsExeKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetMapiBeRequestsExecuting = $loadedData[$aspNetMapiBeRequestsExeKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetMapiFeRequestsTotal = $loadedData[$aspNetMapiFeRequestsTotalKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetMapiBeRequestsTotal = $loadedData[$aspNetMapiBeRequestsTotalKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetRpcFeRequestsExecuting = $loadedData[$aspNetRpcFeRequestsExeKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.AspNetRpcBeRequestsExecuting = $loadedData[$aspNetRpcBeRequestsExeKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxUserCount = $loadedData[$mapiMailboxUserCountKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxConnectionCount = $loadedData[$mapiMailboxConnectionCountKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxAverageLatency = $loadedData[$mapiMailboxAveragedLatencyKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxDispatchTaskThreads = $loadedData[$mapiMailboxDisTaskThreadsKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxDispatchTaskOperations = $loadedData[$mapiMailboxDisTaskOperationsKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxDispatchTaskQueueLength = $loadedData[$mapiMailboxDisTaskQueueLengthKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxDispatchTaskActiveThreads = $loadedData[$mapiMailboxDisTaskActiveThreadsKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxPackets = $loadedData[$mapiMailboxPacketsKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxRequests = $loadedData[$mapiMailboxRequestsKey].TimeHash[$timeDataPointKey].CookedValue
        $cpuMapiConnectionBreakdownResults.MapiMailboxOperations = $loadedData[$mapiMailboxOperationsKey].TimeHash[$timeDataPointKey].CookedValue

        if($timeIndex -ne 0)
        {
            $cpuMapiConnectionBreakdownResults.AspNetMapiFeRequestsExecutedSinceLastDataPoint = $cpuMapiConnectionBreakdownResults.AspNetMapiFeRequestsTotal - $loadedData[$aspNetMapiFeRequestsTotalKey].TimeHash[$timeKeys[$timeIndex - 1]].CookedValue
            $cpuMapiConnectionBreakdownResults.AspNetMapiBeRequestsExecutedSinceLastDataPoint = $cpuMapiConnectionBreakdownResults.AspNetMapiBeRequestsTotal - $loadedData[$aspNetMapiBeRequestsTotalKey].TimeHash[$timeKeys[$timeIndex - 1]].CookedValue
        }

        $timeIndex++
        if($currentPossibleMapiMailboxProcessIdObject -eq $null -or 
            $loadedData[$currentPossibleMapiMailboxProcessIdObject.FullName].TimeHash[$timeDataPointKey].CookedValue -ne $mapiMailboxWebAppProcessId)
        {
            $keyIdProcess = Get-KeyIdProcessForThisId -Id $mapiMailboxWebAppProcessId -PossibleKeys $processesW3wpIdProcessKeys -TimeKey $timeDataPointKey -Data $loadedData
            $currentPossibleMapiMailboxProcessIdObject = Get-CounterSampleToCounterObjectName $loadedData[$keyIdProcess].TimeHash[$timeDataPointKey]
        }
        if($currentPossibleMapiProxyProcessIdObject -eq $null -or 
            $loadedData[$currentPossibleMapiProxyProcessIdObject.FullName].TimeHash[$timeDataPointKey].CookedValue -ne $mapiProxyWebAppProcessId)
        {
            $keyIdProcess = Get-KeyIdProcessForThisId -Id $mapiProxyWebAppProcessId -PossibleKeys $processesW3wpIdProcessKeys -TimeKey $timeDataPointKey -Data $loadedData
            $currentPossibleMapiProxyProcessIdObject = Get-CounterSampleToCounterObjectName $loadedData[$keyIdProcess].TimeHash[$timeDataPointKey]
        }
        if($currentPossibleNetMapiMailboxProcessIdObject -eq $null -or 
            $loadedData[$currentPossibleNetMapiMailboxProcessIdObject.FullName].TimeHash[$timeDataPointKey].CookedValue -ne $mapiMailboxWebAppProcessId)
        {
            $keyIdProcess = Get-KeyIdProcessForThisId -Id $mapiMailboxWebAppProcessId -PossibleKeys $netClrMemoryProcessIdKeyInstances -TimeKey $timeDataPointKey -Data $loadedData
            $currentPossibleNetMapiMailboxProcessIdObject = Get-CounterSampleToCounterObjectName $loadedData[$keyIdProcess].TimeHash[$timeDataPointKey]
        }
        if($currentPossibleNetMapiProxyProcessIdObject -eq $null -or 
            $loadedData[$currentPossibleNetMapiProxyProcessIdObject.FullName].TimeHash[$timeDataPointKey].CookedValue -ne $mapiProxyWebAppProcessId)
        {
            $keyIdProcess = Get-KeyIdProcessForThisId -Id $mapiProxyWebAppProcessId -PossibleKeys $netClrMemoryProcessIdKeyInstances -TimeKey $timeDataPointKey -Data $loadedData
            $currentPossibleNetMapiProxyProcessIdObject = Get-CounterSampleToCounterObjectName $loadedData[$keyIdProcess].TimeHash[$timeDataPointKey]
        }

        $cpuMapiConnectionBreakdownResults.MapiProcessProcessorTime = ($loadedData[("\\{0}\process({1})\% processor time" -f $currentPossibleMapiMailboxProcessIdObject.ServerName,$currentPossibleMapiMailboxProcessIdObject.InstanceName)].TimeHash[$timeDataPointKey].CookedValue)
        $cpuMapiConnectionBreakdownResults.MapiMailboxTimeInGC = ($loadedData[("\\{0}\.net clr memory({1})\% time in gc" -f $currentPossibleNetMapiMailboxProcessIdObject.ServerName,$currentPossibleNetMapiMailboxProcessIdObject.InstanceName)].TimeHash[$timeDataPointKey].CookedValue)
        $cpuMapiConnectionBreakdownResults.MapiMailboxContentionRate = ($loadedData[("\\{0}\.net clr locksandthreads({1})\contention rate / sec" -f $currentPossibleNetMapiMailboxProcessIdObject.ServerName,$currentPossibleNetMapiMailboxProcessIdObject.InstanceName)].TimeHash[$timeDataPointKey].CookedValue)

        foreach($key in $mapiConnectionCounterKeys)
        {
            $dataPoint = $loadedData[$key].TimeHash[$timeDataPointKey]
            $cpuMapiConnectionBreakdownResults.AllDataPoints.Add($dataPoint)
            if($netLocksAndThreadsKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.NetLockAndContentionDataPoints.Add($dataPoint)
            }
            elseif($netClrMemoryTimeInGcKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.NetClrMemoryTimeInGcDataPoints.Add($dataPoint)
            }
            elseif($netClrMemoryProcessIdKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.NetClrMemoryProcessIdDataPoints.Add($dataPoint)
            }
            elseif($w3wpActiveRequestsKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.W3wpActiveRequestsDataPoints.Add($dataPoint)
            }
            elseif($w3wpActiveThreadsCountKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.W3wpActiveThreadsCountDataPoints.Add($dataPoint)
            }
            elseif($w3wpRequestsKeyInstances.Contains($key))
            {
                $cpuMapiConnectionBreakdownResults.W3wpRequestsDataPoints.Add($dataPoint)
            }
        }

        $analyzedResults.Add($cpuMapiConnectionBreakdownResults)
    }

    $saveToDirectory = [System.IO.Directory]::GetParent($filePaths[0])
    $fileInfo = [System.IO.FileInfo]::new($filePaths[0])
    $analyzedResults.DisplayView | Format-Table * -AutoSize | Out-File ($output = "{0}\{1}_{2}_CpuMapiConnectionBreakDownAnalyzer_{3}.txt" -f $saveToDirectory.FullName,$fileInfo.BaseName,$scriptName,(Get-Date).ToString("yyyyMMddHHMM"))
    Write-Host("Output: {0}" -f $output)
    $analyzedResults | Export-Clixml -Depth 15 -Path ($output.Replace(".txt",".xml")) -Encoding UTF8
}
Function Invoke-CpuBreakDownAnalyzer{

    $exchangeCounterKeys = @() 
    $windowsCounterKeys = @() 
    foreach($key in $processesCounterKeys)
    {
        $keyFound = $false
        foreach($containsProcess in $exchangeContainsProcesses)
        {
            if($key.ToLower().Contains($containsProcess))
            {
                $keyFound = $true 
                $exchangeCounterKeys += $key
                break
            }
        }
        if($keyFound){continue}
        foreach($containsProcess in $windowsContainsProcesses)
        {
            if($key.ToLower().Contains($containsProcess))
            {
                $keyFound = $true 
                $windowsCounterKeys += $key 
                break
            }
        }
    }
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    [System.Diagnostics.Stopwatch]$stopWatchCalc = [System.Diagnostics.Stopwatch]::new()
    [System.Collections.Generic.List[System.Object]]$analyzedResults = New-Object -TypeName System.Collections.Generic.List[System.Object]
    foreach($timeDataPoint in $timeKeys)
    {
        
        $dataTimeResults = New-Object PerformanceDataCpuAnalyzer.CpuDataBreakDown
        $dataTimeResults.DateTime = $timeDataPoint.ToString()
        $dataTimeResults.TotalCpuUsage = $loadedData[$cpuTotalKey].TimeHash[$timeDataPoint].CookedValue
        $dataTimeResults.ContextSwitches = $loadedData[$contextSwitchesKey].TimeHash[$timeDataPoint].CookedValue
        $dataTimeResults.ProcessorQueueLength = $loadedData[$processorQueueLengthKey].TimeHash[$timeDataPoint].CookedValue
        foreach($counterKey in $processesCounterKeys)
        {
            $dataPoint = $loadedData[$counterKey].TimeHash[$timeDataPoint]
            if($counterKey.Contains("\process(idle)\% processor time"))
            {
                $dataTimeResults.ProcessIdleTime = $dataPoint.CookedValue
            }
            elseif($counterKey.Contains("\process(_total)"))
            {
                if($counterKey.Contains("\% processor time"))
                {
                    $dataTimeResults.ProcessorTimeTotal = $dataPoint.CookedValue
                }
                elseif($counterKey.Contains("\% privileged time"))
                {
                    $dataTimeResults.PrivilegedTimeTotal = $dataPoint.CookedValue
                }
            }
            elseif($counterKey.Contains("\process(") -and 
                (-not($counterKey.Contains("process(idle)"))))
            {
                if($counterKey.Contains("\% processor time"))
                {
                    $dataTimeResults.ProcessorTimeSum += $dataPoint.CookedValue
                    if($exchangeCounterKeys.Contains($counterKey))
                    {
                        $dataTimeResults.Exchange.ProcessorTimeSum += $dataPoint.CookedValue
                        if($counterKey.Contains($storeWorker))
                        {
                            $dataTimeResults.StoreWorker.ProcessorTimeSum += $dataPoint.CookedValue
                        }
                    }
                    elseif($windowsCounterKeys.Contains($counterKey))
                    {
                        $dataTimeResults.Windows.ProcessorTimeSum += $dataPoint.CookedValue
                    }
                    else
                    {
                        $dataTimeResults.ThirdParty.ProcessorTimeSum += $dataPoint.CookedValue
                    }
                    $dataTimeResults.DataPointsProcessorTime.Add($dataPoint)
                }
                elseif($counterKey.Contains("\% privileged time"))
                {
                    $dataTimeResults.PrivilegedTimeSum += $dataPoint.CookedValue
                    if($exchangeCounterKeys.Contains($counterKey))
                    {
                        $dataTimeResults.Exchange.PrivilegedTimeSum += $dataPoint.CookedValue
                        if($counterKey.Contains($storeWorker))
                        {
                            $dataTimeResults.StoreWorker.PrivilegedTimeSum += $dataPoint.CookedValue
                        }
                    }
                    elseif($windowsCounterKeys.Contains($counterKey))
                    {
                        $dataTimeResults.Windows.PrivilegedTimeSum += $dataPoint.CookedValue
                    }
                    else
                    {
                        $dataTimeResults.ThirdParty.PrivilegedTimeSum += $dataPoint.CookedValue
                    }
                    $dataTimeResults.DataPointsPrivilegedTime.Add($dataPoint)
                }
            }
        }
        $stopWatchCalc.Start()
        $dataTimeResults.CpuBusyTime = (((100 * $processorCoreCount) - $dataTimeResults.ProcessIdleTime) / $processorCoreCount)
        $dataTimeResults.PrivilegedTimeCpuUsage = ($dataTimeResults.PrivilegedTimeSum / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.UserTimeCpuUsage = ($dataTimeResults.TotalCpuUsage - $dataTimeResults.PrivilegedTimeCpuUsage)
        $dataTimeResults.Exchange.ProcessorTimeCpuUsage = ($dataTimeResults.Exchange.ProcessorTimeSum / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.Exchange.PrivilegedTimeCpuUsage = ($dataTimeResults.Exchange.PrivilegedTimeSum / $dataTimeResults.PrivilegedTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.StoreWorker.ProcessorTimeCpuUsage = ($dataTimeResults.StoreWorker.ProcessorTimeSum / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.Windows.ProcessorTimeCpuUsage = ($dataTimeResults.Windows.ProcessorTimeSum / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.Windows.PrivilegedTimeCpuUsage = ($dataTimeResults.Windows.PrivilegedTimeSum / $dataTimeResults.PrivilegedTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.ThirdParty.ProcessorTimeCpuUsage = ($dataTimeResults.ThirdParty.ProcessorTimeSum / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)
        $dataTimeResults.ThirdParty.PrivilegedTimeCpuUsage = ($dataTimeResults.ThirdParty.PrivilegedTimeSum / $dataTimeResults.PrivilegedTimeSum * $dataTimeResults.CpuBusyTime)
        $topProcesses = $dataTimeResults.DataPointsProcessorTime | Sort-Object CookedValue -Descending | Select-Object -First 3
        $dataTimeResults.DisplayView.HighProcess1 = ("{0} - {1}%" -f ((Get-CounterSampleToCounterObjectName -PerformanceCounterSample $topProcesses[0]).InstanceName), ([System.Math]::Round($topProcesses[0].CookedValue / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)))
        $dataTimeResults.DisplayView.HighProcess2 = ("{0} - {1}%" -f ((Get-CounterSampleToCounterObjectName -PerformanceCounterSample $topProcesses[1]).InstanceName), ([System.Math]::Round($topProcesses[1].CookedValue / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)))
        $dataTimeResults.DisplayView.HighProcess3 = ("{0} - {1}%" -f ( (Get-CounterSampleToCounterObjectName -PerformanceCounterSample $topProcesses[2]).InstanceName), ([System.Math]::Round($topProcesses[2].CookedValue / $dataTimeResults.ProcessorTimeSum * $dataTimeResults.CpuBusyTime)))
        $stopWatchCalc.Stop()
        $analyzedResults.Add($dataTimeResults)
    }
    Write-Host("took {0} seconds" -f $stopWatch.Elapsed.TotalSeconds)
    Write-Host("Took {0} seconds to do calculations" -f $stopWatchCalc.Elapsed.TotalSeconds)
    $saveToDirectory = [System.IO.Directory]::GetParent($filePaths[0])
    $fileInfo = [System.IO.FileInfo]::new($filePaths[0])
    $analyzedResults.DisplayView | Format-Table * -AutoSize | Out-File ($output = "{0}\{1}_{2}_{3}.txt" -f $saveToDirectory.FullName,$fileInfo.BaseName,$scriptName,(Get-Date).ToString("yyyyMMddHHMM"))
    Write-Host("Output: {0}" -f $output)
    $analyzedResults | Export-Clixml -Depth 15 -Path ($output.Replace(".txt",".xml")) -Encoding UTF8
}
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
    [array]$counterKeys = $loadedData.Keys
    [array]$tempTimeKeys = $loadedData[$counterKeys[0]].TimeHash.Keys
    $counterObject = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $loadedData[$counterKeys[0]].TimeHash[$tempTimeKeys[0]]
    $index = $counterKeys.IndexOf("\\{0}\processor(_total)\% processor time" -f $counterObject.ServerName)
    [array]$timeKeys = $loadedData[$counterKeys[$index]].TimeHash.Keys | Sort-Object 
    $processorCoreCount = ($counterKeys | ?{$_ -like "*\processor(*)\% processor time" -and $_ -notlike "*\processor(_total)\% processor time"}).Count
    $processesCounterKeys = @()
    $mapiConnectionCounterKeys = @()
    $processesIdProcessKeys = @()
    $processesW3wpIdProcessKeys = @()
    foreach($key in $counterKeys)
    {
        if($key.Contains("\processor(_total)\% processor time"))
        {
            $cpuTotalKey = $key
        }
        elseif($key.Contains("\system\context switches/sec"))
        {
            $contextSwitchesKey = $key 
        }
        elseif($key.Contains("\system\processor queue length"))
        {
            $processorQueueLengthKey = $key
        }
        elseif($key.Contains("\process("))
        {
            if(!($key.EndsWith("\id process")))
            {
                $processesCounterKeys += $key 
            }
            else 
            {
                $processesIdProcessKeys += $key
                if($key -like "\\*\process(w3wp*)\id process")
                {
                    $processesW3wpIdProcessKeys += $key 
                }
            }
        }
        elseif($MapiConnectionBreakDown)
        {
            foreach($mapiCounter in $mapiConnectionBreakDownCounters)
            {
                if($key -like $mapiCounter)
                {
                    $mapiConnectionCounterKeys += $key 
                    break
                }
            }
        }
    }

    Invoke-CpuBreakDownAnalyzer
    if($MapiConnectionBreakDown)
    {
        Invoke-CpuMapiConnectionBreakDownAnalyzer
    }
}

Main 
