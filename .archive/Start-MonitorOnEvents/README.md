# Start-MonitorOnEvents
Script that is used to monitor a list of servers for a particular event to occur. It notifies you once you are seeing the issue that you specify and stops the data collection. 

# Parameters

Parameter | Description
----------|------------
EnableEmailNotification | Enables the ability to send email notification to an SMTP address to be notified where we are within the script. Default value $false.
SMTPSender | The sender of the email that you would like the message to appear who it is coming from. 
SMTPRecipients | The recipients that you wish to have the email sent to.
SMTPServerNameOrIPAddress | The Server Name or the IP Address that is responsible to accept the email from. 
MailCreds | If anonymous isn't acceptable by the SMTP server, you may need to provide credentials to be used to properly send a message. 
Servers | The list of servers that you wish to monitor and collect data from. Default value $env:COMPUTERNAME
MDBFailureItemTagMonitorEnabled | To able to Mailbox Database Failure Item Tag Monitor feature of the script. Default value $false.
MDBFailureItemTags | The list of failure tag types that you wish to monitor for. Default values are 38,39 (HungStoreWorker, UnaccessibleStoreWorker).
ActiveDatabaseGUIDs | The GUIDs of the databases that you wish to only monitor. If this is left blank, any event for the filtered Tag IDs will trigger the monitor's condition to be met. 
EventLogName | The name of the Event Log that you wish to have be monitored. Default value "Application"
EventID | The Event ID that you are looking for. Default value "2080"
EventProviderName | The name of the source that you want to be focused on for this event. 
EventLevel | The Event Level that you are looking for. (Information, Error, Warning)
EventTaskDisplayNameFilter | The additional filter that you wish to be looking for if the event ID is common but the task category isn't. This filter happens after the Get-WinEvent command completes.
EventMessageFilter | The additional filter that you wish to be looking for in the message property of the event. This filter happens after the Get-WinEvent command completes.
EventSusspendMonitorServerHostWriters | This suspends the display stating that we found events from the Get-WinEvent. 
EventTimeUpdateIntervalInSeconds | The interval that we update the StartTime of the FilterHashTable. This is useful when you are querying a very active Windows Event Logs. Default value 30.
EventTimeUpdateEnabled | This enables the feature to update the StartTime of the FilterHashTable based off the value of EventTimeUpdateIntervalInSeconds.
EnableExtraTracing | Enables the feature to collect Extra Tracing on the servers. 
ExtraTraceConfigFileContent | The content that needs to be placed in the EnabledTraces.config file on the servers.
EnableExperfwizManager | Enables the feature to manage Experfwiz on the servers. 
ExperfwizInterval | Sets the interval of the Experfwiz to collect the data. Default value 1.
EnableNetshTrace | Enables the feature to manage Netsh Traces on the servers. 
NetshTraceMaxSize | Sets the Netsh trace size. Default value 2048.
NetshProviderString | Sets a custom provider string for the Netsh trace command. 
NetshScenario | Set a scenario to standard collection. Default value "netconnection"
IssueLimit | The amount of time we will allow the monitor condition to be met to completely stop the script. Default value 1. 
SaveAllDataPath | The location where we have all the saved out data storing to locally on each server. Default value is the current directory. 
StopDataCollectors | Switch that will stop and remove all the data collector sets. 

# How To Use

Customize how you would like to collect data from the servers by the above data collection options/features. Then provide the Event that we are trying to see occur on any of the servers. 

Use the sample Start-MonitorOnEvents.ps1.config to see how you setup the config file to allow the script to run with the same settings every time. 