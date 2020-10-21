# Get-Smb1ServerSettings
Function that is used to get the SMB1 settings of a computer and provide back an object containing the results from the checks.

# Parameters

Parameter | Description
----------|-------------
ServerName | The server that you want to get the data from. Default value $env:COMPUTERNAME
Windows2012R2OrGreater | Also does Get-WindowsFeature to check for SMB1 feature. Default is true
CatchActionFunction | Pass a script block to be executed during a catch action

# Properties

Property | Description
---------|------------
RegistryValue | The registry value of "SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\SMB1"
SmbServerConfiguration | The output from Get-SmbServerConfiguration
WindowsFeature | The output from Get-WindowsFeature 
Smb1Enabled | Internal logic that determines if Smb1 is truly enabled or not based off the settings from the 3 checks that we do.

# How To Use

Use the following sample code within your script: 

```
$smb1ServerSettings = Get-Smb1ServerSettings -ServerName "Solo-E19A" -CatchActionFunction $scriptBlock

if ($smb1ServerSettings.Smb1Enabled)
{
    Write-Host ("Server has SMB1 Enabled")
}
else
{
    Write-Host ("Server does not have SMB1 Enabled")
}

```