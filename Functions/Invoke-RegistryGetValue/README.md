# Invoke-RegistryGetValue
Function that is used to get registry values in a try catch block. 

# Parameters 

Parameter | Description 
----------|------------
RegistryHive | Pass a custom RegistryHive that you wish to open up in the registry. Default value "LocalMachine".
MachineName | Pass the machine name of the registry that you wish to open. Required.
SubKey | Pass the SubKey name that you wish to open within the Registry Hive. Required.
GetValue | Pass the registry key that you wish to get a value from. 
ReturnAfterOpenSubKey | If you just want to pass back the result from the SubKey, set this to true.
DefaultValue | If we aren't able to get a value from the registry, it will return a custom default value.
CatchActionFunction | Pass a custom Script Block action to occur if a catch happens. 

# How To Use 

Use the following example code within a script: 

```
$value = Invoke-RegistryGetValue -MachineName $env:COMPUTERNAME -SubKey "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -GetValue "Release" -CatchActionFunction ${Function:Invoke-CatchActions}
```