# New-PerformanceCounterMonitorThresholdObject
Function that is used to create an object for you to be able to monitor performance counters on a computer going above a particular average or a min/max threshold limit.

# Parameters 

Parameter | Description
----------|-------------
PerformanceThresholdCounters | This is a required parameter that provides the counters that we which to monitor and the values that we want to monitor them at. 
SampleInterval | The interval, in seconds, that you are pulling data from Get-Counter. Default 1. 
MaxSamples | The max number of samples to get before it is returned back from Get-Counter. Default 10. 
SleepInSeconds | After calling the method GetMonitorResults(), this will sleep for this value in seconds before returning a Passed status code. Default 0. 
UpdateEveryXMinutes | This will display and update to the screen that we are still actively working and monitoring. We will only display this notification every so often. Default 5 minutes.
LoggerObject | Used to pass an object that issued to log the data that is written to screen or the verbose data in the background. *
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs. 
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs. 

* For more information about the PerformanceThresholdCounters go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/Get-PerformanceThresholdCounters
* For more information about the LoggerObject go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-LoggerObject

# Methods 

Method | Description
-------|------------
GetPerformanceCounterMinMaxAverageCorrectly(object PerformanceCounterSamples) | Provides a current Min, Max, and Avg of the the counter samples that was provided to the method. 
WriteUpdate() | Displays an update to the screen, only if we have passed the timeframe for an update to occur. 
GetData() | Runs Get-Counter for all the full counter paths that we have provided from PerformanceThresholdCounters. We return an array of counter samples that are grouped by the full counter path. 
GetMonitorResults() | This is the main Method that you should use, run this and it will return either [PerformanceCounterMonitorThreshold.StatusCode]::Passed or [PerformanceCounterMonitorThreshold.StatusCode]::Success.<br>It will run GetData() then analyze the data at that point to determine if we are above our custom threshold of that particular counter. 


# Properties 

Unique properties of the object that aren't passed as a possible parameter in the construction of the object. 

Property | Description 
---------|------------
Counters | Is a list of all the Counters from PerformanceThresholdCounters.Keys
NextUpdateTime | The next time we update the screen to display that we are still working. 
ThresholdMetDetails | The details of how we determined that we met the threshold. 
ThresholdMetObjectDetails | An Object that contains the following properties: Counter, MetValue, Details, and Type. Counter is the counter that met the threshold. MetValue is the value that was provided to reach that threshold. Details contains the same information as ThresholdMetDetails. Type is the same ThresholdType value provided in PerformanceThresholdCounters for this counter. 

# How To Use 

Here is an example of some sample code of how to use this object. 

```
$counter = "LogicalDisk(C:)\Avg. Disk Sec/Read" 

#Call Get-PerformanceThresholdCounters: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/Get-PerformanceThresholdCounters 
$performanceThresholdCounters = Get-PerformanceThresholdCounters -PerformanceCounter $counter -ThresholdType "GreaterThan" -AverageThreshold 0.030 -MaxThreshold 0.100 -Servers @("ComputerA","ComputerB")

$performanceCounterMonitorThreshold = New-PerformanceCounterMonitorThresholdObject -PerformanceThresholdCounters $performanceThresholdCounters -MaxSamples 20 -SleepInSeconds 1

do{
    #some other code if required
}while(($performanceCounterMonitorThreshold.GetMonitorResults()) -eq [PerformanceCounterMonitorThreshold.StatusCode]::Passed)

#Threshold is now met, do work 

Write-Host("Counter that reached limit: '{0}'" -f ($counter = $performanceCounterMonitorThreshold.ThresholdMetObjectDetails.Counter))
Write-Host("Threshold Value: {0}" -f $performanceCounterMonitorThreshold.ThresholdMetObjectDetails.MetValue)

Write-Verbose("Threshold Details: {0}" -f $performanceCounterMonitorThreshold.ThresholdMetDetails)

$serverName = $counter.Substring(2, ($counter.IndexOf("\", 2)-2))
#Do action on $serverName if not local

```