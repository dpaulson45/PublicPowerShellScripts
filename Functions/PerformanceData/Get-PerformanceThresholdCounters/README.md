# Get-PerformanceThresholdCounters
Function that is used to create an object that can be easily passed to New-PerformanceCounterMonitorThresholdObject. 

# Parameters 

Parameter | Description
----------|-------------
PerformanceCounter | Used to pass the single counter type that you wish to aline with this set of AverageThreshold, MaxThreshold, ThresholdType values. It is recommended to only pass the counter Object and the Counter name and leave the instances wild, unless you want to specify the instances. Example: "LogicalDisk(*)\avg. disk sec/read"
Servers | Pass a list of possible servers that you want to monitor. If none is provided, the local computer is used. 
AverageThreshold | Provide the value that you wish to have set for your Average Threshold value to trigger a condition met. 
MaxThreshold | Provide the value that you wish to have set for your Max Threshold value to trigger a condition met. This could be a Less Than value or Greater Than Value depending on what you provide for the ThresholdType.
ThresholdType | Determines if we are looking for the thresholds to go below or go above the value limit. 
ActionPreference | To do a throw if we detect an error within Get-Counter. However, if no counters are return we will also throw regardless of this value. 

# How to use the function

Here is how the object looks like when it is returned: 

```
[hashtable]$PerformanceThresholdCounters
    [key = [string](Full Counter Path)] -- Example: "\\ComputerName\logicaldisk(c:)\avg. disk sec/write" 
        [value]
            [double]AverageThreshold
            [double]MaxThreshold
            [string]ThresholdType -- Current Supported "GreaterThan/LessThan"
```

Use the following sample code within your script: 

```
$performanceThresholdCounters = @{}
$counters = @("LogicalDisk(*)\Avg. Disk Sec/Read","LogicalDisk(*)\Avg. Disk Sec/Write")

foreach($counter in $counters)
{
    $tempHash =  Get-PerformanceThresholdCounters -PerformanceCounter $counter -ThresholdType "GreaterThan" -AverageThreshold 0.030 -MaxThreshold 0.100 -Servers @("ComputerA","ComputerB")
    foreach($key in $tempHash.Keys)
    {
        $performanceThresholdCounters.Add($key, $tempHash[$key])
    }
}

#Call New-PerformanceCounterMonitorThresholdObject: https://github.com/dpaulson45/PublicPowerShellScripts/blob/master/Functions/New-PerformanceCounterMonitorThresholdObject/New-PerformanceCounterMonitorThresholdObject.ps1

$performanceCounterMonitorThreshold = New-PerformanceCounterMonitorThresholdObject -PerformanceThresholdCounters $performanceThresholdCounters 
```