[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$PerformanceCounterSamples
)


#Function Version 1.0

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
        public CounterAccuracy Accurarcy; 
        public object[] AllData; 
        public int GetDataCount { get { return AllData.Count() - 1;  } }
        public Hashtable TimeHash; 
        public IEnumerable<object> GetData { get {return AllData.Skip(1); } }
        public object FirstSample {get {return GetData.First(); } }
        public object LastSample {get {return GetData.Last(); } }

        public CounterData()
        {
            this.Accurarcy = new CounterAccuracy();
            this.TimeHash = new Hashtable();
        }
    }
}


"@


########################
#
# Template Functions
#
########################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
Function Get-CounterSampleToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)

#Function Version 1.1

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




########################
#
# End Template Functions
#
########################

########################
#
# Functions 
#
########################

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
