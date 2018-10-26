[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$Perfcounters,
[Parameter(Mandatory=$false)][int]$SampleInterval = 1,
[Parameter(Mandatory=$false)][int]$MaxSamples = 10,
[Parameter(Mandatory=$false)][int]$SleepTime = 0,
[Parameter(Mandatory=$false)][int]$UpdateEveryXMinutes = 5,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)
<#
This works remotely as well 
[hashtable]$Perfcounters
    [Key = \\serverName\logicaldisk(c:)\avg. disk sec/write]
        [value]
            [double]AverageThreshold
            [double]MaxSpikeThreshold
            [double]MinDipThreshold
            [string]ThresholdType - GreaterThan/LessThan
#>

#Function Version 1.0
if($SampleInterval -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SampleInterval. Provide a value greater than 1."
}
if($MaxSamples -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSamples. Provide a value greater than 1."
}
if($UpdateEveryXMinutes -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid UpdateEveryXMinutes. Provide a value greater than 1"
}

foreach($key in $Perfcounters.Keys)
{
    try 
    {
        Get-Counter -Counter $key -ErrorAction stop | Out-Null
    }
    catch 
    {
        $info = "Failed to provide valid key '{0}'. Error: {1}" -f $key, ($Error[0].Exception)
        throw [System.Management.Automation.ParameterBindingException] $info 
    }
    if([string]::IsNullOrEmpty($Perfcounters[$key].ThresholdType) -or ($Perfcounters[$key].ThresholdType -ne "GreaterThan" -and $Perfcounters[$key].ThresholdType -ne "LessThan"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a ThresholdType property with a string value of 'GreaterThan' or 'LessThan'"
    }
    if($Perfcounters[$key].AverageThreshold -eq $null -or $Perfcounters[$key].AverageThreshold.Gettype().Name -ne "Double")
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a AverageThreshold property with a double type value." 
    }
    if(($Perfcounters[$key].ThresholdType -eq "GreaterThan") -and (($Perfcounters[$key].MaxSpikeThreshold -eq $null -or $Perfcounters[$key].MaxSpikeThreshold.Gettype().Name -ne "Double")))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a MaxSpikeThreshold property with a double type value, when ThresholdType is set to GreaterThan." 
    }
    if(($Perfcounters[$key].ThresholdType -eq "LessThan") -and ($Perfcounters[$key].MinDipThreshold -eq $null -or $Perfcounters[$key].MinDipThreshold.Gettype().Name -ne "Double"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a MinDipThreshold property with a double type value, when ThresholdType is set to LessThan." 
    }
}

Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($this.VerboseFunctionCaller -eq $null)
        {
            Write-Verbose $WriteString
        }
        else 
        {
            $this.VerboseFunctionCaller($WriteString)
        }
    }
    
    Function Write-HostWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($this.HostFunctionCaller -eq $null)
        {
            Write-Host $WriteString
        }
        else
        {
            $this.HostFunctionCaller($WriteString)
        }
    }


Add-Type -TypeDefinition @"
    namespace PerfCounterMonitor
    {
        public enum StatusCode
        {
            None,
            Passed,
            ThresholdMet
        }
    }

"@ 

Function Get-Counters {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[System.Object]])]

    [System.Collections.Generic.List[System.Object]]$counterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    foreach($key in $Perfcounters.Keys)
    {
        $counterList.Add($key)
    }

    return $counterList
}

$perfMonitorObject = New-Object pscustomobject 

$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "PerformanceCounters" -Value $Perfcounters
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "MaxSamples" -Value $MaxSamples
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepTime" -Value $SleepTime
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "Counters" -Value (Get-Counters)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetDetails" -Value ([string]::Empty)
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}



if($HostFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

#Master Template https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-PerformanceCounterMinMaxAverageCorrectly/Get-PerformanceCounterMinMaxAverageCorrectly.ps1
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetPerformanceCounterMinMaxAverageCorrectly" -Value {

[CmdletBinding()]
param(
[object]$PerformanceCounterSamples
)

<#
Calculate Averages 
Average calculation for Average counters taken from these references:
https://msdn.microsoft.com/en-us/library/ms804010.aspx
https://blogs.msdn.microsoft.com/ntdebugging/2013/09/30/performance-monitor-averages-the-right-way-and-the-wrong-way/

[arrayorlist]PerformanceCounterSamples
    CookedValue
    RawValue
    TimeBase
    SecondValue
    CounterType
#>
    
    #Function Version 1.0
    if($PerformanceCounterSamples -eq $null -or $PerformanceCounterSamples.Count -le 1)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounterSamples. Provide more than 1 sample as well."
    }

    $min = [int64]::MaxValue
    $max = [int64]::MinValue

    foreach($sample in $PerformanceCounterSamples)
    {
        if($sample.CookedValue -lt $min) {$min = $sample.CookedValue}
        if($sample.CookedValue -gt $max) {$max = $sample.CookedValue}
    }

    if($PerformanceCounterSamples[0].CounterType -like "AverageTimer*")
    {
        $numTicksDiff = $PerformanceCounterSamples[-1].RawValue - $PerformanceCounterSamples[0].RawValue
        $frequency = $PerformanceCounterSamples[-1].TimeBase
        $numOpsDif = $PerformanceCounterSamples[-1].SecondValue
        if($frequency -ne 0 -and $numTicksDiff -ne 0 -and $numOpsDif -ne 0)
        {
            $avg = (($numTicksDiff/ $frequency) / $numOpsDif)
        }
        else 
        {
            $avg = 0
        }
    }
    else 
    {
        $avg = ($PerformanceCounterSamples | Measure-Object -Property CookedValue -Average).Average
    }

    $minMaxAvgObj = New-Object pscustomobject

    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Min" -Value $min
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Max" -Value $max
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Avg" -Value $avg

    return $minMaxAvgObj
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {

    if([DateTime]::Now -gt $this.NextUpdateTime)
    {
        $this.WriteHostWriter("[{0}] : Everything is passing checks thus far..." -f ([DateTime]$dt = [DateTime]::Now))
        $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
    }
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetData" -Value {
    $measure = Measure-Command{$results = (Get-counter -Counter $this.Counters -SampleInterval $this.SampleInterval -MaxSamples $this.MaxSamples).CounterSamples | Group-Object Path}
    $this.WriteVerboseWriter("Took {0} seconds to get the data" -f $measure.TotalSeconds)
    return $results
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetMonitorResults" -Value {
    
    $results = $this.GetData()
    foreach($counterResults in $results)
    {
        $counterName = $counterResults.Name 
        $counterPassedObj = $this.PerformanceCounters[$counterName]
        $minMaxAvgResults = $this.GetPerformanceCounterMinMaxAverageCorrectly($counterResults.Group)
        $Global:MinMaxAvgResults = $minMaxAvgResults
        if($counterPassedObj.ThresholdType -eq "GreaterThan")
        {
            if($minMaxAvgResults.Max -ge $counterPassedObj.MaxSpikeThreshold)
            {
                $details = "Met max spike threshold. Current max spike is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Max, $counterPassedObj.MaxSpikeThreshold, $counterName
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -ge $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdMet = $true 
            }
        }
        elseif($counterPassedObj.ThresholdType -eq "LessThan")
        {
            if($minMaxAvgResults.Min -le $counterPassedObj.MinDipThreshold)
            {
                $details = "Met min dip threshold. Current min dip is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Min, $counterPassedObj.MinDipThreshold, $counterName
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -le $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdMet
            }   
        }
        if($thresholdMet)
        {
            $this.ThresholdMetDetails = $details
            $this.WriteHostWriter($details)
            return [PerfCounterMonitor.StatusCode]::ThresholdMet
        }
    }
    $this.WriteUpdate()
    Start-Sleep $this.SleepTime
    return [PerfCounterMonitor.StatusCode]::Passed
}


return $perfMonitorObject