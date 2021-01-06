# New-TraceLogmanObject
Function that is used to create an object that is used to manage a Trace Logman Data Collector Set. 

# Parameters 

Parameter | Description 
----------|------------
TraceLogmanName | Provide a Custom Name to the Data Collector Set. This allows you to manage multiple Data Collector Sets on the same machine. Default value: CustomTraceLogmanCapture
LogFormat | Change the options from being circular or just in binary format. Default is bincirc. 
MaxSizeMB | Provide an option to be able to change the max file size of the Data Collector Set. Default 1024 MB. 
SaveFileDirectory | Provide a path to save out the data to. 
Provider | Provide a provider(s) that you would like to trace. 
FileVersioning | Provides a File Versioning to the file name. This can not be used when Event Trace Sessions is enabled. Default: "mmddhhmm". Note: Currently not in use. 
NumberBuffers | Provide a min an max number of buffers. Default is 16, 16. 
BufferSize | Provides a buffer size of the trace. Default 1024. 
Mode | Provide an option to change the mode of the trace. Default: globalsequence.
Servers | Provide a list of servers that you wish to manage with this object. 
EventTraceSessionsEnabled | Enables sending the command to Event Trace Sessions without saving or scheduling. This means you don't need to use StartLogman() or DeleteLogman() when this option is enabled. Default $true. 
OverwriteExistingFile | Enables the option to have logman overwrite the existing log file that is there. Default $false. 
VerboseEnabled | Used to enable hidding verbose logging within the object's methods. 
LoggerObject | Used to pass an object that issued to log the data that is written to screen or the verbose data in the background. *
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs. 
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs. 

* For more information about the LoggerObject go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-LoggerObject

# Methods 

With the exception of GetFailedStatusServers() which returns a list, the methods return a TraceLogman.StatusCode of Success or Failed. A failed can occur if a single server in the list of Servers that was provided in the object had an error occurred on the logman action. Use GetFailedStatusServers and look at the ServersStatus property of the object to determine the cause of the failure. 

Method | Description
-------|------------
CreateLogman() | Used to create the Logman Data Collector Set on all the servers passed with Servers. <br> This can fail if the Logman Data Collector Set is created and already running. 
StartLogman() | Used to start the Logman Data Collector Set on all the servers passed with Servers. 
StopLogman() | Used to stop the Logman Data Collector Set on all the servers passed with Servers. 
DeleteLogman() | Used to delete the Logman Data Collector Set
GetFailedStatusServers() | Used to return all the servers that are currently set to Failed status code. 
ExecuteLogmanAction(TraceLogman.Action, List) | Used primarily for internal use and is called by StartLogman(), StopLogman(), and DeleteLogman(). As the actions are so similar, it was just better to create a method to handle all these action types. 


# Properties 

Unique properties of the object that aren't passed as a possible parameter in the construction of the object. 

Property | Description 
---------|------------
ServersStatus | A hashtable with the key of the server name itself. The values provide the current LogmanStatusCode of the server and the results of the last ran logman command within DebugResults properties. 
