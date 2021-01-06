# Get-Smb1ServerSettings
Function that is used to get the SMB1 settings of a computer and provide back an object containing the results from the checks.

# Parameters

Parameter | Description
----------|-------------
ServerName | The server that you want to get the data from. Default value $env:COMPUTERNAME
CatchActionFunction | Pass a script block to be executed during a catch action

# Properties

Property | Description
---------|------------
SmbServerConfiguration | The output from Get-SmbServerConfiguration
WindowsFeature | The output from Get-WindowsFeature 
Smb1Status | Internal logic that determines if SMB1 Installed or blocked

### SMB1 Status

Flag Value | Description
-----------|------------
0 | Unknown
1 | Failed to run Get-WindowsFeature. If on Server 2012 this is to be expected.
2 | SMB1 Feature is installed.
4 | SMB1 Feature is not installed.
8 | Failed to run Get-SmbServerConfiguration to get the block setting.
16 | SMB1 Feature is not Blocked.
32 | SMB1 Feature is Blocked.


# How To Use

Use the following sample code within your script: 

```
$smb1ServerSettings = Get-Smb1ServerSettings -ServerName "Solo-E19A" -CatchActionFunction $scriptBlock

switch ($smbServerSettings.Smb1Status)
{
    36 {Write-Host "SMB1 Is not installed and being blocked"} # Recommended
    34 {Write-Host "SMB1 is installed and being blocked"} # Recommended to remove SMB1
    33 {Write-Host "SMB1 is install status is unknown and being blocked"} #Likely installed as we failed to get the Windows Feature which might mean server 2012.
    20 {Write-Host "SMB1 is not installed and not being blocked"}
    18 {Write-Host "SMB is installed and not being blocked"} # Security whole
    17 {Write-Host "SMB1 is install status is unknown and not being blocked"} # Security whole likely on 2012
    12 {Write-Host "SMB1 is not installed and failed to get the blocked status"}
    10 {Write-Host "SMB1 is installed and failed to get the blocked status"}
    9 {Write-Host "SMB1 is install status is unknown and failed to get the blocked status"}
    0 {Write-Host "Unknown status"}
}


```