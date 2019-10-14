# Start-ActiveDirectoryAndClientTracing

This script is created for assisting any client type to collect different types of data collections from both the client and the Active Directory environments. This script is designed currently to run on the client machine and does remote execution of commands against the Active Directory server that you wish to collect data from. 

In some environments, the client admin user isn't able to access the Active Directory environment. This script does have the ability to still work, providing an admin user from the Active Directory environment provides their credentials on start of the script. For security reasons, do **not** use the parameter ActiveDirectoryRemoteCredentials via a stored variable, except in a lab environment. The credentials of the Active Directory environment is store a variable with a Script scope, so the credentials is discarded after the script stops executing. The security threat is minimal, unless your client machine is compromised. 

# Data Collections 

This is a current list of data collections that is available within the script. 

- LDAP Tracing (client)
- Procdump (client)
- Performance Data Collector Set (client & AD)
- Active Directory Diagnostics (default AD system data collector set)

# Monitor Types

This is a current list of the ways to monitor for an issue to determine when to take action. 

- Performance Counter by a Threshold 

**NOTE:** Currently this is the only option available, however, more could be added. 

# Parameters 

Parameter | Description
----------|------------
ClientProcdumpCollectionEnabled | Enables the ability to execute a procdump on the client machine(s) based off the other settings provided. This expects the procdump to be from SysInternals. 
ClientProcdumpBinaryLocation | Provide a valid path to the procdump binary location on each client machine. 
ClientProcdumpProcessName | Provide a valid name of the process that you wish to dump on. 
ClientPerformanceDataCollectionSetEnabled | Enables the ability to collect performance data from the client machine(s).
ClientPerformanceDataCollectionSetLogmanName | Provide a unique name to the performance data collection set on the client machine(s).
ClientPerformanceDataCollectionSetCounters | Provide a list of counters that you wish to have collected within the performance data collector set on the client machine(s). 
ClientPerformanceDataCollectionSetInterval | Set the interval for what you wish to collect the performance data collector set from the client machine(s).
ClientPerformanceDataCollectionSetMaxSize | Set the max size of the performance data collector set on the client machine(s). 
ClientLDAPTracingEnabled | Enables the ability to collect LDAP tracing from the client machine(s). 
ClientLDAPTracingLogmanName | Provide a unique name to the LDAP tracing data on the client machine(s). 
ClientLDAPTracingProvider | Provide an option to change the current settings of the provider settings for the LDAP tracing that we enable on the client machine(s). 
ClientLDAPTracingMaxSizeMB | Set the max size of the LDAP tracing on the client machine(s). 
ClientLDAPTracingStopAfterIssueDetected | Enables that ability to stop after an issue is detected, as some data we wish to continue to collect while an issue is still occurring for a bit of time. This stops after the procdump is collected from the client machine that sees the issue, if that is enabled. 
ActiveDirectoryPerformanceDataCollectorSetEnabled | Enables the ability to collect normal performance data on the Active Directory machine(s). 
ActiveDirectoryPerformanceDataCollectorSetCounters | Provide a list of counters that you wish to have collected within the performance data collector set on the Active Directory machine(s). 
ActiveDirectoryPerformanceDataCollectorSetInterval | Set the interval for what you wish to collect the performance data collector set from the Active Directory machine(s). 
ActiveDirectoryPerformanceDataCollectorSetMaxSize | Set the max size of the performance data collector set on the Active Directory machine(s). 
ActiveDirectoryPerformanceDataCollectorSetLogmanName | Provide an unique name for the performance data collector set on the Active Directory machine(s). 
ActiveDirectoryDiagnosticsEnabled | Enables the ability to collect the default System Active Directory Diagnostics data collector set that is on the server by default. 
ActiveDirectoryDiagnosticsAfterIssueOccursOnly | Enables to have this data only collected after an issue is detected from the monitor type. 
ActiveDirectoryPerformanceDataCollectorSetStopAfterDiagnosticsStarted | Enables the option to have the initial performance data collector set to be stopped after we start the System Active Directory Diagnostics on the Active Directory machine(s).
ActiveDirectoryRemoteCredentialNotNeeded | Enables the option to not request for Active Directory Credentials when we have an Active Directory data collection type enabled. This only needs to be set to true if you have the ability to run Invoke-Command against the Active Directory machine(s) with your current logged in session. 
ActiveDirectoryRemoteCredentials | **DO NOT USE** For security reason, it is recommended to not use this with a passing variable. This variable that you are using is a global variable to that session and can be a security risk. The intent of this parameter is for lab work and testing only. 
MonitorCounterTypeEnabled | Enables the ability to monitor the client machine(s) based off a performance counter threshold. You can monitor this by a single counter with a threshold type of greater than or less than. 
MonitorCounterTypeCounterName | Provide the counter that you wish to monitor on the client machine(s). 
MonitorCounterTypeAverageThreshold | Provide the counter's average threshold that you want to see to determine an issue has occurred. 
MonitorCounterTypeMaxThreshold | Provide the counter's max threshold value that you want to see to determine an issue has occurred. 
MonitorCounterTypeThresholdType | Provide the threshold type of that counter. The current options are to provide "LessThan" or "GreaterThan", so once the values of the max and average threshold go less than or greater than, we will trigger that we detected an issue. 
MonitorCounterTypeMaxSamples | Provides the max samples that we wish to get from the counter to determine an issue. <br>**NOTE:** The more data points you have here the longer it is going to take to return the results and analyze the values to determine if an issue is occurring. 
MonitorCounterTypeSleepInSeconds | Provide an automatic sleep break within the script before we return the results. 
MailNotificationEnabled | Enables the option to send an email message when an issue has occurred, or when the script has completed correctly. 
MailNotificationSender | The email address that is doing the sending of the message. 
MailNotificationRecipients | The list of people that we wish to send the notification to. 
MailNotificationSmtpServers | A list of server(s) that we want to use as an option to deliver the message. Only one is required. 
MailNotificationRequireCredentials | If the SMTP server requires authentication to be used, a Get-Credential popup window will appear to store those credentials in a script scope variable. 
MailNotificationMessageSubject | Provide a custom option of the base name of the emails that you would be receiving. 
ActiveDirectoryServers | The list of Active Directory server(s) that you wish to be collecting data from. 
ActiveDirectorySavePath | The path where you would like the data to be saved on the Active Directory machine(s).
ClientServers | The list of client server(s) that you wish to monitor and collect data from.
ClientSaveAllDataPath | The path where you would like the data to be saved on the client machine(s).
MinutesToContinueDataCollectionAfterIssueDetected | The minutes to continue to collect the data on the Active Directory and client machine(s) after an issue was detected. 
MinimizeIssueScriptEnabled | Enables the ability to invoke a minimization script that you provide a path to that would be running against that problem server that is detected. 
MinimizeIssueScriptPath | The path to the script that you wish to invoke after an issue is detected and after the MinutesToContinueDataCollectionAfterIssueDetected time has passed. 
MinutesWaitDurationBetweenIssues | The time that we wait to determine if an issue has occurred again. We do start the data collection again right away, but we just wait to check to see if the monitoring conditions are met. 
IssueCount | The amount of times we will loop and detect issues before we exit out of the script. 
StopDataCollectors | This switch is used if the script was abruptly stopped before the conditions were met to automatically stop all the data collectors. If you have issues starting up the script because of data collector sets are running, use this switch to stop them. 

**NOTE:** All the paths that are provided are expected to be the on all the servers of that type.

To understand more about the different monitors, data collection types and features, please visit the following: 

- [Performance Counter Monitor Threshold](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-PerformanceCounterMonitorThresholdObject)
- [Performance Logman - Data Collector Set](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-PerformanceLogmanObject)
- [Procdump Manager](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-ProcdumpManagerObject)
- [Trace Logman - Data Collector Set](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-TraceLogmanObject)
- [Script Configuration File](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/Import-ScriptConfigFile)
- [Mail Message](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-MailMessageObject)

# How To Use

## Script Configuration 

To make running the script easy for a consistent configuration every single time it is run, you can use the feature that is built into the script that will import the script's expected paramters from its Start-ActiveDirectorAndClientTracing.ps1.config file. In here you can set all the above paremters the way that you want. This allows you to just execute the script without providing any of the parameters, and it just reads it from the config file that you have located in the same location. 

You can include only the paramters that you want to actively use, or all of them and just make sure you follow the correct syntax for each parameter to avoid any issues. Located in this directory, I have an example setup for the current configuration that uses every feature available in the script. If you don't want to use a particular feature, just set that piece to false or remove it from the configuration file. 

If you have any questions on how to configure the script configuration file, please review the current settings or the [Import-ScriptConfigurationFile](https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/Import-ScriptConfigFile) function documentation. 

## Running the Script

After you have configured the script configuration file (recommended), you can just run the script in an Administrator PowerShell session from the location of the script and all the required configuration files. 

```
.\Start-ActiveDirectoryAndClientTracing.ps1
```

After the issue count has been reached, the script will automatically clean up and remove the data collectors. 

**NOTE:** If the script is stopped prior to the issue limit is reached, or you were having issues starting the script initially, it is recommended to use -StopDataCollectors switch to remove all the configurable data collectors within the script to avoid any issues. 