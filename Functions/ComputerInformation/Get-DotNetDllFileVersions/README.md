# Get-DotNetDllFileVersions
Function that is used to particular file information for .NET Framework. It returns a hashtable with the key of the file name that you want to look at. 

# Parameters 

Parameter | Description
----------|------------
ComputerName | The computer name that you wish to collect the information on.
FileNames | The names of the files that you wish to get information on. 
CatchActionFunction | The custom script block function that you wish to be called if an error occurs. 

# How to use

Using the following sample code to use this function

```
$info = Get-DotNetDllFileVersions -ComputerName "ADT-E19A" -FileNames @("System.Data.dll","System.Configuration.dll")

$info["System.Data.dll"].ProductVersion 
$info["System.Configuration.dll"].ProductVersion 
```