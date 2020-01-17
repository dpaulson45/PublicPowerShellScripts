# Get-TimeZoneInformationRegistrySettings
Function that is used to get the registry information at "SYSTEM\CurrentControlSet\Control\TimeZoneInformation" for detecting a possible DST issue for when DST rules change. 

# Parameters 

Parameter | Description 
----------|------------
MachineName | The computer that you would like to read from the registry settings and test against. 
CatchActionFunction | To pass an action to occur if we fail to execute the ability to read from the registry. 

# Properties

Property | Description 
---------|------------
DynamicDaylightTimeDisabled | The registry value for DynamicDaylightTimeDisabled.
TimeZoneKeyName | The registry value for TimeZoneKeyName.
StandardStart | The registry value for StandardStart.
DaylightStart | The registry value for DaylightStart.
DstIssueDetected | An extremely high likely hood of a DST time zone issue can occur, especially if there was a recent DST Time Zone Rule change.  
ActionsToTake | An array of verbage of the issues detected.

# How To Use 

Use the following sample code within your script: 

```
$dstTimeZoneSettings = Get-TimeZoneInformationRegistrySettings -MachineName "ServerA" 
if($dstTimeZoneSettings.ActionsToTake.Count -gt 0)
{
    Write-Host("Found issues within the DST Settings.")
    foreach($issue in $dstTimeZoneSettings.ActionsToTake)
    {
        Write-Host("`t{0}" -f $issue)
    }
}
else 
{
    Write-Host("DST Settings set correctly.")
}
```