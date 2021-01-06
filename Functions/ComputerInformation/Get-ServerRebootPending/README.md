# Get-ServerRebootPending 
Function that is used to determine if a server has a reboot pending on it by checking the common locations. Returns an object of all the locations that we find that could cause a server to be pending a reboot. 

# Paramters 

Parameter | Description
----------|------------
ServerName | The name of the server that you want to check to see if it is pending a reboot. 
CatchActionFunction | Pass a script block to be executed during a catch action.

# Properties 

Property | Description
---------|-------------
SccmReboot | Stores the object for CimMethod for class name CCM_ClientUtilities.
PendingFileRenameOperations | Boolean to determine if a server is pending reboot based off of "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\" item PendingFileRenameOperations.
ComponentBasedServicingPendingReboot | Boolean to determine if a server is pending reboot based off of HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending
AutoUpdatePendingReboot | Boolean to determine if a server is pending reboot based off of HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired
SccmRebootPending | If the SccmReboot has either PendingReboot or IsHardRebootPending is set to true.
PendingReboot | If any of the properties to determine a reboot is pending is set to true. 

# How To Use 

Use the following sample code within your script: 

```
$rebootStatus = Get-ServerRebootPending -ServerName "ServerA"
if($rebootStatus.PendingReboot)
{
    Write-Host("Server is pending reboot")
}
else 
{
    Write-Host("Server is not pending reboot")
}
```