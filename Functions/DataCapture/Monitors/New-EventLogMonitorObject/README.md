# New-EventLogMonitorObject
Function that is used to create an object for you to be able to monitor for a particular event that occurs on the servers that you provided to monitor.

# Parameter
Parameter | Description 
----------|------------
LogName | The Event Log Name. Default Application. 
EventID | The Event ID number. Required. 
ProviderName | The name of source of the event that you can filter on.
Level | The level of the event filter. 
TaskDisplayNameFilter | The filter on the event of the TaskDisplayName property. 
MessageFilter | The filter on the event of the Message property. 
Servers | Provide a list of servers that you wish to monitor with this object.
WriteUpdateMinuteInterval | The interval that we do a write to show that we are still passing the monitor checks or not. Default is 5. 
SleepTime | The amount of time in seconds that is paused between checking the servers for the monitor event while in the MonitorLoop() method. Default value 1 second. 
EventFilterStartTimeUpdateIntervalInSeconds | The interval that we will update the Start Time of the FilterHashtable of the events. This is useful if you are querying the event log that will contain a lot of data that needs to be filter down more yet with TaskDisplayNameFilter or MessageFilter. This allows the query to execute more quickly.
EventFilterStartTimeUpdateEnabled |  Enables the feature to update the Start Time of FilterHashtable within the MonitorLoop() method. Otherwise, the Start Time will not be updated during this time.
SusspendMonitorServerHostWriters | Susspend the write host operation if you expect results to return from the Filter Hash Table and it still needs to be filtered by MessageFilter and TaskDisplayNameFilter. 
VerboseEnabled | Used to enable hidding verbose logging within the object's methods.
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs.
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs.

# Methods 

Method | Description
-------|------------
GetConditionServers() | Returns a list of servers that had the condition met. The chances are that it will be a single server.
GetEventData() | Returns the event(s) that hit the condition from the servers in a string array format with properties preselected. 
GetRawEventData() | Returns the event(s) that hit the condition from the servers in a EventLogRecord type. 
MonitorLoop([int]$DurationInMinutes) | Will be in a continuous loop for the duration provided running MonitorServers(). Once the condition or duration is met, the loop will stop and return the status. If a 0 is provided for the duration, the loop will continue till a condition is met. Default value is 0. 
MonitorServers() | Executes the query to get the Windows Events from the server based off the Filter Hash Table. If additional filters are required (MessageFilter and TaskDisplayNameFilter) those will then be evaluated to see if the condition is met. After the method executes, it returns a status. 
ResetStatus() | Resets the status of all the servers to Passed status. This is recommend to be run after every time a condition is met prior to entering another monitoring loop. 
UpdateStartTime([int]$SubtractSeconds) | Updates the StartTime for the FilterHashtable query to be the current time. This will also update the NextUpdateFilterStartTime property. The $SubtractSeconds default value is 0. Primarily this is use for when the EventFilterStartTimeUpdateEnabled is set to true. 

# Properties 

Property | Description
---------|------------
FilterHashtable | The Filter Hashtable is what is used to narrow down the results from the Get-WinEvent command running on the server. 
NextUpdateTime | The next time that the object will notify the time that everything has passed. This allows the user to know that everything is working when monitoring for an issue for a long period of time. 
NextUpdateFilterStartTime | The next time that we will update the Start Time for the FilterHashtable.
ServerEventData | Stores the individual server events that caused the condition to be met. 
ServerStatus | Stores the individual server status to determine which server hit the condition. 

# How To Use

Use the following example code within a script:

```
#How to setup the Event Log Monitor Object
#Option 1 - Basic use when that event ID occurs
$Script:eventLogMonitorObject = New-EventLogMonitorObject -LogName "Application" -EventID 2080 -Servers @("ComputerA","ComputerB")

#Option 2 - How to sue the Message Filter. 
$Script:eventLogMonitorObject = New-EventLogMonitorObject -LogName "Microsoft-Exchange-MailboxDatabaseFailureItems/Operational" -EventID 1 -Servers @("ComputerA","ComputerB") -MessageFilter "Database=CN=DB01"

#Option 3 - Filter on an Error event level when you have a lot of event IDs that are the same. 
$Script:eventLogMonitorObject = New-EventLogMonitorObject -LogName "Microsoft-Exchange-ActiveMonitoring/ProbeResult" -EventID 2 -Servers @("ComputerA","ComputerB") -Level 2 -MessageFilter "ImapCTPProbe/MSExchangeImap4"

#How to use the Event Log Monitor Object 
#You can place the Event Log Monitor object in a while loop if you want the data collection option to repeat.
while($true)
{
    #Start Data Collection
    $Script:eventLogMonitorObject.ResetStatus()
    $Script:eventLogMonitorObject.MonitorLoop()
    #Stop Data Collection
}

#If you have multiple different monitoring conditions you can use an action like this
while($true)
{
    #start data collections 
    $Script:eventLogMonitorObject.ResetStatus()
    while($true)
    {
        if($Script:eventLogMonitorObject.MonitorServers() -eq [EventLogMonitor.StatusCode]::ConditionMet)
        {
            break;
        }
        if($secondMonitor.MonitorServers() -eq ConditionMet)
        {
            break;
        }
    }
    #stop data Collections
}

#You can also get the data from the Event Log Monitor object after a condition is met
$eventData = $Script:eventLogMonitorObject.GetEventData()

```