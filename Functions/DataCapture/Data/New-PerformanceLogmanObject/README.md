# New-PerformanceLogmanObject
Function that is used to create an object that is used to manage a Performance Logman Counter Data Collector Set.

# Parameters 

Parameter | Description
----------|-------------
PerformanceLogmanName | Provide a Custom Name to the Data Collector Set. This allows you manage multiple Data Collector Sets on the same machine.
LogFormat | Change the options from being Circular Enabled (Default - bincirc) or just the binary format. 
MaxSizeMB | Provide an option to be able to change the max file size of the Data Collector Set. Default 4096 MB. 
PerformanceCounters | Provide an array of possible counters that you would like to collect on the machine. 
SampleInterval | Provide a custom value for the interval that we pull the counter data. Valid values are 1 - 30. 
SaveFileDirectory | Provide a path to save out the data to.
FileVersioning | Provides a File Versioning to the performance binary file name. Default "mmddhhmm". Note: Currently not in use. 
Servers | Provide a list of servers that you wish to manage with this Performance Logman object. 
RemoteCredentials | Used for when you need to manage a Data Collector Set on a remote machine and you can't use your current logged account to execute logman against the machine. 
IncreaseMaxSizeTimes | Used for adjusting the amount of times you wish to update the Logman Data Collector Set for when starting the logman doesn't work. This is typically because for some reason it doesn't like the value that you provided for the file size. So we just loop through this amount of times and attempt to start it with a different value each time. Default is 20 attempts. 
MaxStartUpdateLoop | Used for adjusting the amount of times you wish to attempt to start the logman due to a file that already exists. After the start attempt, the Data Collector Set is automatically updated so we try to start it again. Want to limit the amount of times we do this, so we will only go up to this value. Default value is 100. 
SystemDataCollectorSet | Used for when you want to manage a System Data Collector Set, like "System\Active Directory Diagnostics". When this is enabled, only options are to start and stop the data collector set. Default value: False. 
VerboseEnabled | Used to enable hidden verbose logging within the object's methods. 
LoggerObject | Used to pass an object that issued to log the data that is written to screen or the verbose data in the background. *
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs. 
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs. 

* For more information about the LoggerObject go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-LoggerObject

# Methods 

With the exception of GetFailedStatusServers() which returns a list, the methods return a PerformanceLogman.StatusCode of Success or Failed. A failed can occur if a single server in the list of Servers that was provided in the object had an error occurred on the logman action. Use GetFailedStatusServers and look at the ServersStatus property of the object to determine the cause of the failure. 

Method | Description
-------|------------
CreateLogman() | Used to create the Logman Data Collector Set on all the servers passed with Servers. <br> This can fail if the Logman Data Collector Set is created and already running. 
StartLogman() | Used to start the Logman Data Collector Set on all the servers passed with Servers. This can take some time as this does take into account some issues that could occur on each server. <br> 1. If the server doesn't like the file size that we provide, it will automatically increase the value till the IncreaseMaxSizeTimes value is reached. <br> 2. If we try to start the logman and the file already exists, we will attempt to re-start the logman till MaxStartUpdateLoop is reached or we find a file name that isn't already in use.
StopLogman() | Used to stop the Logman Data Collector Set on all the servers passed with Servers. 
DeleteLogman() | Used to delete the Logman Data Collector Set
GetFailedStatusServers() | Used to return all the servers that are currently set to Failed status code. 
ExecuteLogmanAction(PerformanceLogman.Action, List) | Used primarily for internal use and is called by StartLogman(), StopLogman(), and DeleteLogman(). As the actions are so similar, it was just better to create a method to handle all these action types. 

# Properties 

Unique properties of the object that aren't passed as a possible parameter in the construction of the object. 

Property | Description 
---------|------------
ServersStatus | A hashtable with the key of the server name itself. The values provide the current LogmanStatusCode of the server and the results of the last ran logman command within DebugResults properties. 
