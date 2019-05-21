Function Get-ServerOperatingSystemVersion {
[CmdletBinding()]
param(
[string]$OSBuildNumberVersion
)

#Function Version 1.4
<#
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>

if($OSBuildNumberVersion -eq [string]::Empty -or $OSBuildNumberVersion -eq $null)
{
    Write-VerboseWriter("Getting the local machine version build number")
    $OSBuildNumberVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
    Write-VerboseWriter("Got {0} for the version build number" -f $OSBuildNumberVersion)
}
else 
{
    Write-VerboseWriter("Passed - [string]OSBuildNumberVersion : {0}" -f $OSBuildNumberVersion)
}

[string]$osReturnValue = ""
switch ($OSBuildNumberVersion) 
{
    "6.0.6000" {$osReturnValue = "Windows2008"}
    "6.1.7600" {$osReturnValue = "Windows2008R2"}
    "6.1.7601" {$osReturnValue = "Windows2008R2"}
    "6.2.9200" {$osReturnValue = "Windows2012"}
    "6.3.9600" {$osReturnValue = "Windows2012R2"}
    "10.0.14393" {$osReturnValue = "Windows2016"}
    "10.0.17713" {$osReturnValue = "Windows2019"}
    default {$osReturnValue = "Unknown"}
}

Write-VerboseWriter("Returned: {0}" -f $osReturnValue)
return [string]$osReturnValue
}