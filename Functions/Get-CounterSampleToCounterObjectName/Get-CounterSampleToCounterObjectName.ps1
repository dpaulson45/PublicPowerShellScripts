[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)

#Function Version 1.0

Add-Type @"

namespace PerformanceCounters
{
    public class PerformanceCounterName
    {
        public string FullName; 
        public string ServerName; 
        public string ObjectName; 
        public string InstanceName; 
        public string CounterName; 
    }
}

"@

$counterObj = New-Object -TypeName PerformanceCounters.PerformanceCounterName
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
$counterObj.FullName = $FullName
$counterObj.ServerName = ($FullName.Substring(2,($endOfServerIndex - 2)))
$counterObj.ObjectName = ($FullName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObj.InstanceName = $instanceName
$counterObj.CounterName = ($FullName.Substring($startOfCounterIndex))

return $counterObj