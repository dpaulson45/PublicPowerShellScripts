# New-ExtraLogmanObject
Function that is used to create an object for you to be able to manage extra that would be running on a set number of servers.

**NOTE** This is done in a circular mode only at this time.

# Parameters 

Parameter | Description 
----------|------------
LogmanName | The name of the logman data collector set. Default value "ExchangeLogman"
FileName | The custom file name of the ETL that is saved out on the server(s). If none is provided, the LogmanName is used. 
EtlFileSize | The file size that the ETL is maxed out at. Default is 400MB 
FileDirectory | The directory where the files will be saved out to. 
Provider | The provider of the logman data collector set. Default "Microsoft Exchange Server 2010".
AppendVersioningToFile | Adds the file versioning information to the file on creation of the ETL. Default is "mmddhhmm"
Servers | The list of servers that you are wanting to have the extra trace running on.
ExtraTraceConfigFileContent | The full content of the EnabledTraces.Config file that needs to be created on every server.

# Methods 

Method | Description
-------|------------
SaveExtraConfigToAllServers() | Saves the configuration file to all the servers. This is saved to C:\EnabledTraces.Config. 
StartLogman() | Starts the logman on all the servers. 
StopLogman() | Stops the logman on all the servers.
DeleteLogman() | Deletes the logman on all the servers.
CreateLogman() | Creates the logman on all the servers. 
CheckLogmanStatus() | Sets the ServersStatus[ServerName].LogmanStatusCode to a Running, Stopped, or a None status.

# Properties

Property | Description 
---------|------------
ServersStatus | Stores the Status code of all the different actions as well as the raw results from the logman command to each respective server. 

# How To Use 

Use the following example code within a script: 

```
$ExtraTraceConfigFileContent = @"
TraceLevels:Debug,Warning,Error,Fatal,Info,Performance,Function,Pfd
Data.ApplicationLogic:Cafe
FilteredTracing:No
InMemoryTracing:No
@"

$Script:extraObject = New-ExtraLogmanObject -FileDirectory "C:\Temp\Data" -ExtraTraceConfigFileContent $ExtraTraceConfigFileContent -Servers @("ADT-E16A","ADT-E16B")

if($Script:extraObject.SaveExtraConfigToAllServers() -ne [ExtraLogman.StatusCode]::Success)
{
    Write-Host("Failed to save the Extra Logman to all the servers.")
    exit 
}
else 
{
    Write-Host("Saved the Extra Logman to all the servers.")
}
if($Script:extraObject.DeleteLogman() -ne [ExtraLogman.StatusCode]::Success)
{
    #If this happens, it isn't a bad thing. We always want to delete the Logman first before we start incase we changed some of the settings.
}
 if($Script:extraObject.CreateLogman() -ne [ExtraLogman.StatusCode]::Success)
 {
     Write-Host("Failed to create the Extra Logman on all the servers.")
     exit 
 }
 else
 {
     Write-Host("Created teh Extra Logman on all the servers.")
 }

 #Create monitors and/or other data collector options. Once ready start the extra trace

 if($Script:extraObject.StartLogman() -ne [ExtraLogman.StatusCode]::Success)
 {
     Write-Host("Failed to start Extra Logman on all the servers.")
     exit 
 }
 else
 {
     Write-Host("Started Extra Logman on all the servers.)
 }

 #Once monitor condition is met, stop the data collector
 if($Script:extraObject.StopLogman() -ne [ExtraLogman.StatusCode]::Success)
 {
     Write-Host("Failed to stop Extra Logman on all the servers.")
     #Don't stop, continue to stop other data collectors.
 }
 else 
 {
     Write-Host("Stopped the Extra Logman on all the servers.")
 }

```