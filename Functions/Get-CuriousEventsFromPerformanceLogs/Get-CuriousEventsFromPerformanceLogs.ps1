Function Get-CuriousEventsFromPerformanceLogs {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$LoadedPerfObject,
[Parameter(Mandatory=$false)][object]$MultiThresholdConditionObject,
[Parameter(Mandatory=$false)][string]$ExportDirectory,
[Parameter(Mandatory=$false)][string]$SaveName,
[Parameter(Mandatory=$false)][bool]$ReturnData = $true 
)

#Function Version 1.1
<#
    [hashtable]LoadedPerfObject - return object from Load-PerformanceCounters:  https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
    
    [object]MultiThresholdConditionObject - All conditions must be met for it to be a curious event
        [hashtable]MultiThresholdCondition- key counter path '\\ServerName\processor(_total)\% processor time'
                [double/int]Threshold
                [string]ThresholdType
        [int]CuriousTimeSpanInSeconds //How many seconds the conditions need to be met for it to be a curious timeframe event
        [int]ViewTimeSpanInSecondsBefore //How many seconds to collect datapoints before the curious timeframe
        [int]ViewTimeSpanInSecondsAfter //How many seconds to collect datapoints after the curious timeframe
#>

Add-Type -TypeDefinition @"

    namespace PerfCounterMonitorThreshold
    {
        public enum ThresholdType
        {
            Unknown,
            GreaterThan,
            GreaterThanOrEqual,
            LessThan,
            LessThanOrEqual
        }
    }

"@

########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
        
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}
    
########################
#
# Template Functions
#
########################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Export-PerformanceDataToCSVFile/Export-PerformanceDataToCSVFile.ps1
Function Export-PerformanceDataToCSVFile {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$LoadedPerfObject,
[Parameter(Mandatory=$true)][string]$FullSavePath
)

#Function Version 1.0
#[hashtable]LoadedPerfObject - return object from Load-PerformanceCounters:  https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}

########## Parameter Binding Exceptions ##############
if(Test-Path $FullSavePath)
{
    $throwString = "This file already exists '{0}'" -f $FullSavePath
    throw [System.Management.Automation.ParameterBindingException] $throwString
}

$firstKey = ($LoadedPerfObject.GetEnumerator() | Select-Object -First 1).Name
$masterCount = $LoadedPerfObject[$firstKey].AllData.Count 
[System.Collections.Generic.List[System.Object]]$timeList = New-Object -TypeName System.Collections.Generic.List[System.Object]
$index = 0
while($index -lt $masterCount)
{
    $addTimer = $true 
    $timeFrameObject = New-Object pscustomobject 

    foreach($key in $LoadedPerfObject.Keys)
    {
        if($addTimer)
        {
            $timeFrameObject | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value ($LoadedPerfObject[$key].AllData[$index].TimeStamp)
            $addTimer = $false 
        }
        $timeFrameObject | Add-Member -MemberType NoteProperty -Name $key -Value ($LoadedPerfObject[$key].AllData[$index].CookedValue)
    }
    $timeList.Add($timeFrameObject)
    $index++
}

$timeList | Export-Csv $FullSavePath
}
# End Function Export-PerformanceDataToCSVFile




# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-CounterDataObject/New-CounterDataObject.ps1
Function New-CounterDataObject {
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
# New-CounterDataObject -- Template Functions
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
# End New-CounterDataObject -- Template Functions
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

}
# End Function New-CounterDataObject


    
    
########################
#
# End Template Functions
#
########################

########################
#
#   Script Functions
#
########################

Function Test-ThresholdType {
param(
[Parameter(Mandatory=$true)][double]$CookedValue,
[Parameter(Mandatory=$true)][string]$ThresholdType,
[Parameter(Mandatory=$true)][double]$Threshold 
)
    switch($ThresholdType)
    {
        ([PerfCounterMonitorThreshold.ThresholdType]::GreaterThan) {if($CookedValue -gt $Threshold){return $true} else{ return $false }}
        ([PerfCounterMonitorThreshold.ThresholdType]::GreaterThanOrEqual) {if($CookedValue -ge $Threshold){return $true} else{ return $false }}
        ([PerfCounterMonitorThreshold.ThresholdType]::LessThan) {if($CookedValue -lt $Threshold){return $true} else{ return $false }}
        ([PerfCounterMonitorThreshold.ThresholdType]::LessThanOrEqual) {if($CookedValue -le $Threshold){return $true} else{ return $false }}
    }
    
}



########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($ReturnData -eq $false -and [string]::IsNullOrEmpty($SaveName) -and [string]::IsNullOrEmpty($ExportDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide how to process the data. It needs to be returned or saved out. Use ReturnData or SaveName & ExportDirectory parameters to `
    accomplish this." 
}
if($ReturnData -eq $false -and [string]::IsNullOrEmpty($SaveName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveName"
}
if($ReturnData -eq $false -and ([string]::IsNullOrEmpty($ExportDirectory) -or (Test-Path $ExportDirectory)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExportDirectory"
}

if($MultiThresholdConditionObject -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MultiThresholdConditionObject"
}
foreach($key in $MultiThresholdConditionObject.MultiThresholdCondition.Keys)
{
    if([string]::IsNullOrEmpty($MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType) -or 
    ($MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::GreaterThan -and 
    $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::GreaterThanOrEqual -and 
    $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::LessThan -and 
    $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::LessThanOrEqual ))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ThresholdType property with a string value of 'GreaterThan', 'GreaterThanOrEqual', 'LessThan', or 'LessThanOrEqual'"
    }
    if($MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold -eq $null -or 
    ($MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold.GetType().Name -ne "Double" -and $MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold.GetType().Name -ne "Int32"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a Threshold property with a Int32 or double type value."
    }
    
}
if($MultiThresholdConditionObject.CuriousTimeSpanInSeconds -eq $null -or 
    ($MultiThresholdConditionObject.CuriousTimeSpanInSeconds.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.CuriousTimeSpanInSeconds -lt 1))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a CuriousTimeSpanInSeconds property with a Int32 type value at a value of 1 or greater."
    }
    if($MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore -eq $null -or
    ($MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore -lt 0))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ViewTimeSpanInSecondsBefore property with a Int32 type value at a value of 0 or greater."
    }
    if($MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter -eq $null -or
    ($MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter -lt 0))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ViewTimeSpanInSecondsAfter property with a Int32 type value at a value of 0 or greater."
    }

$masterKeys = @()
foreach($key in $MultiThresholdConditionObject.MultiThresholdCondition.Keys)
{
    $masterKeys += $key 
}





$curiousEventsTimes = @() 
$mainKey = $masterKeys[0]
$actualMulti = $masterKeys.Count -gt 1
foreach($datapoint in $LoadedPerfObject[$mainKey].GetData)
{
    if((Test-ThresholdType -CookedValue ($datapoint.CookedValue) `
    -ThresholdType ($MultiThresholdConditionObject.MultiThresholdCondition[$mainKey].ThresholdType) `
    -Threshold ($MultiThresholdConditionObject.MultiThresholdCondition[$mainKey].Threshold)))
    {
        $allTrue = $false 
        $timeKey = $datapoint.TimeStamp 
        if($actualMulti)
        {
            $indexKey = 1
            $allTrue = $true #All Condidions must be true before we go to the next step
            while($indexKey -lt $masterKeys.Count)
            {
                $thisKey = $masterKeys[$indexKey++]
                if(-not (Test-ThresholdType -CookedValue ($LoadedPerfObject[$thisKey].TimeHash[$timeKey].CookedValue) `
                -ThresholdType ($MultiThresholdConditionObject.MultiThresholdCondition[$thisKey].ThresholdType) `
                -Threshold ($MultiThresholdConditionObject.MultiThresholdCondition[$thisKey].Threshold)))
                {
                    $allTrue = $false
                    break 
                }
            }
        }

        if(($actualMulti -and $allTrue) -or ($actualMulti -eq $false))
        {
            $curiousEventsTimes += $timeKey
        }
    }
}

#now loop through the times to find times that are within the threshold limit. 
$index = 0 
$alreadyAdded = [datetime]::MinValue
$filteredCuriousEventsTimes = @()
while($index -lt $curiousEventsTimes.Count)
{
    $currentTime = $curiousEventsTimes[$index]
    $nextTime = $curiousEventsTimes[$index + 1]
    $timeSpan = $nextTime - $currentTime
    if($timeSpan.TotalSeconds -le $MultiThresholdConditionObject.CuriousTimeSpanInSeconds)
    {
        if($currentTime -ne $alreadyAdded)
        {
            $filteredCuriousEventsTimes += $currentTime
        }
        $filteredCuriousEventsTimes += $nextTime
        $alreadyAdded = $nextTime
    }
    $index++
}

[System.Collections.Generic.List[System.Object]]$masterIssueList = New-Object -TypeName System.Collections.Generic.List[System.Object]
$startIssueIndex = 0 
$endIssueIndex = 1
while($endIssueIndex -lt $filteredCuriousEventsTimes.Count)
{
    $singleIssue = @() 
    $singleIssue += $filteredCuriousEventsTimes[$startIssueIndex]
    while($endIssueIndex -lt $filteredCuriousEventsTimes.Count)
    {
        $currentTime = $filteredCuriousEventsTimes[$endIssueIndex]
        $singleIssue += $currentTime
        $nextTime = $filteredCuriousEventsTimes[$endIssueIndex + 1]
        $timeSpan = $nextTime - $currentTime
        if($timeSpan.TotalSeconds -gt $MultiThresholdConditionObject.CuriousTimeSpanInSeconds)
        {
            $masterIssueList.Add($singleIssue)
            $startIssueIndex = ++$endIssueIndex
            $endIssueIndex++ 
            break; 
        }
        $endIssueIndex++ 
    }
}

[System.Collections.Generic.List[System.Object]]$allIssuesDataPoints = New-Object -TypeName System.Collections.Generic.List[System.Object]
foreach($issue in $masterIssueList)
{
    $startTime = $issue[0].AddSeconds(-$MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore)
    $endTime = $issue[-1].AddSeconds($MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter)
    $issueStartTime = $issue[0]
    $hashCounterPathKey = @{}
    
    foreach($key in $LoadedPerfObject.Keys)
    {
        $counterDataPoints = @() 
        foreach($datapoint in $LoadedPerfObject[$key].GetData)
        {
            if($datapoint.TimeStamp -ge $startTime -and $datapoint.TimeStamp -le $endTime)
            {
                $counterDataPoints += $datapoint
                continue; 
            }
            if($datapoint.TimeStamp -gt $endTime)
            {
                break; 
            }
        }
        $counterDataObject = New-CounterDataObject -PerformanceCounterSamples $counterDataPoints
        $hashCounterPathKey.Add($key, $counterDataObject)
    }

    $obj = New-Object -TypeName pscustomobject 
    $obj | Add-Member -MemberType NoteProperty -Name "StartOfIssue" -Value $issueStartTime
    $obj | Add-Member -MemberType NoteProperty -Name "HashData" -Value $hashCounterPathKey
    $allIssuesDataPoints.Add($obj)
}

if($ExportDirectory -ne $null -and $SaveName -ne $null)
{

    $saveLocation = "{0}\{1}_StartOfIssueTime_{2}.csv"
    foreach($issueTime in $allIssuesDataPoints)
    {
        $savePath= $saveLocation -f $ExportDirectory, $SaveName,($issueTime.StartOfIssue.ToString("yyyyMMddHHmmss"))
        Export-PerformanceDataToCSVFile -LoadedPerfObject $issueTime.HashData -FullSavePath $savePath
    }
}

if($ReturnData)
{
    return $allIssuesDataPoints
}
}