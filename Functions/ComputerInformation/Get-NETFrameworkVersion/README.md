# Get-NETFrameworkVersion
Function that is used to get the Major .NET Framework version from the system by reading the registry. It will return a custom object that contains the Friendly .NET Framework Version name, the minimum value for that .NET Framework version, and the registry value that was returned. If you already have a registry value, you can pass that in this method and it will not try to lookup that value again.

# Parameters 

Parameter | Description
----------|------------
MachineName | The machine name that you wish to look up the .NET Framework Version information of. Default is $env:ComputerName
NetVersionKey | The .NET Framework Version Key found in the registry or the value that you would like to get the friendly name for. Default is -1, which will try to get the value from the registry at that point.
CatchActionFunction | The custom script block function that you wish to be called if an error occurs. 

# How To Use

```
$netVersion = Get-NETFrameworkVersion -MachineName "ADT-E16A" -CatchActionFunction ${Function:Invoke-CustomCatchFunction}

Write-Host("Friendly Name: {0} | Registry Value: {1} | Minimum Value: {2}" -f $netVersion.FriendlyName, $netVersion.RegistryValue, $netVersion.MinimumValue)

$friendlyName = Get-NETFrameworkVersion -NetVersionKey 460900 

Write-Host("Friendly Name: {0}" -f $friendlyName.FriendlyName)
```