# New-MDBFailureItemTagMonitor
Function that is used to create an object for you to monitor the Mailbox Database Failure Item Tag to occur. This is only able to do it locally on the server.

# Parameters 

Parameter | Description 
----------|------------
TagIDs | The enum values for the failure type that you are troubleshooting. Default values are 38,39 (HungStoreWorker, UnaccessibleStoreWorker).
DatabaseGUIDsToMonitor | The GUIDs of the databases that you wish to only monitor. If this is left blank, any event for the filtered Tag IDs will trigger the monitor's condition to be met.
VerboseEnabled | Used to enable hidding verbose logging within the object's methods.
LoggerObject | Used to pass an object that issued to log the data that is written to screen or the verbose data in the background. *
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs.
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs.

* For more information about the LoggerObject go here: https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-LoggerObject

# Methods

Method | Description 
-------|------------
MonitorEvents() | The method that executes the query to determine if a condition is met at this time. 
ResetStatus() | Resets the status of the Mailbox Database Failure Item Tag Monitor object back to the default value and updates the search time.
MonitorLoop() | Enters a Monitoring loop till the condition is met. This will automatically sleep every 5 seconds before the next query executes. Once the condition is met, a status of [MDBFailureItemTag.StatusCode]::ConditionMet is returned. 

# Properties 

Property | Description
---------|------------
ConditionMetDB | The database GUID that hit the condition. 
FilterByDBGuidEnabled | Determines that we are going to look for a particular DB(s) for the Mailbox Failure Item. This is enabled by default if any values are provided in the DatabaseGUIDsToMonitor parameter on creation.
MonitorEventObject | Stores the object that is created from New-EventLogMonitorObject

# How To Use 

Use the following example code within a script: 

```

$mdbFailureItemTagMonitor = New-MDBFailureItemTagMonitor -DatabaseGUIDsToMonitor @("d32d32db-1944-4d93-b7b6-83ba9beb40f7")

while($true)
{
    #start data collectors
    $mdbFailureItemTagMonitor.ResetStatus()
    $mdbFailureItemTagMonitor.MonitorLoop()
    Write-Host("Issue occurred at {0} for database: {1}" -f [DateTime]::Now, $mdbFailureItemTagMonitor.ConditionMetDB)
    #stop data collectors 
    if($enoughIssuesOccurred)
    {
        break;
    }
}

```