# New-ProcdumpManagerObject
Function that is used to create an object that is used to manage a Procdump command to dump on a particular issue that we want to control from a script. 

**NOTE:** This object does require Invoke-Command to work properly on all the servers that you wish to manage with it. 

# Parameters 

Parameter | Description 
----------|------------
BinaryProcdumpExe | Provide a full path on each server to where the procdump.exe binaries are located.
ProcessName | Option to provide a process name that you wish to dump on. This is the recommended option when there aren't duplicate process names on a system like w3wp.exe. 
ProcessIDToServer | If ProcessName isn't a valid option, then use a hashtable for the Key to be the Server Name and the value be the PID of the process that you wish to dump. 
DumpFolder | Provide a valid dump folder location so the dump file isn't dump in the default location of where the Invoke-Command is running. 
DumpWithMA | Provides that we want to dump the process with full memory. Default is True. This can't be used with DumpWithMP. 
DumpWithMP | Provides that we want to dump the process with thread and handle information. Default is False. 
NumberOfDumps | Customize the number of dumps you wish to use within procdump.exe. Default is 3. 
SecondsWait | Provides a waiting period between each dump being taken. Default value is 30 seconds. 
Servers | Provide a list of servers that you wish to manage with this procdump manager object. 
VerboseEnabled | Used to enable hidden verbose logging within the object's methods. 
LoggerObject | Used to pass an object that issued to log the data that is written to screen or the verbose data in the background. *
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs. 
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs. 

* For more information about the LoggerObject go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-LoggerObject

# Methods 

Method | Description
-------|------------
ValidateProcessOnServers() | Verifies that the Process Name or PID actually exists on all the Servers. It is recommended to run this after object creation and if you use PID, to use this prior to executing the dump action. 
DumpOnServer(String ServerName) | Execute the dump on the Server that you pass to this method. It will create and execute the dump based off the parameters that you provided to it. 

# Properties 

Unique properties of the object that aren't passed as a possible parameter in the construction of the object. 

Property | Description 
---------|------------
UsingProcessIDToServer | To determine if we are using the HashTable of ProcessIDToServer or not. 