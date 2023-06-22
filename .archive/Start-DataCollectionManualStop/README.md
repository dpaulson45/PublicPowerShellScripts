# Start-DataCollectionManualStop

This script is used for data collection options where you can easily reproduce the issue and just hit enter to manually stop the data collection after it is created. This is useful for scenarios where you are doing a network capture to avoid those getting to big and avoid the need to go from server to server to collect the data. 

# Data Collection Options 

The current list of options that you have available to collect within the script. 

- Extra Trace 
- Netsh Trace 

# Parameters 

Parameter | Description
----------|------------
SaveAllDataPath | The location where you would like all the data to be saved to locally on each server.
Servers | All the servers that you would like this data to be collected from. 
EnableExtraTracing | Enable the feature for collecting extra tracing from the servers.
ExtraTraceConfigFileContent | The full content of the EnabledTraces.config file. 
EnableNetshTracing | Enable the feature for collecting extra tracing from the servers.
NetshTraceMaxSize | The max size of the netsh trace. Default is 2048 MB. 
NetshProviderString | The netsh provider string. 
NetshScenario | The scenario for the Netsh collection to be used. 
StopDataCollectors | Stops and removes all the data collectors in the script. 