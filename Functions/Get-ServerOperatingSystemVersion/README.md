# Get-ServerOperatingSystemVersion
Function that is used to be able to return a string of what your Server OS is on. 

# Parameters 

Parameter | Description
----------|------------
OsCaption | The OS Caption from WMI object. Not required. 

# How to use

Use the following sample code within your script: 

```
$r = Get-ServerOperatingSystemVersion -OsCaption "Microsoft Windows Server 2019 Datacenter"
```