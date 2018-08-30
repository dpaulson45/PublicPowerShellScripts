[CmdletBinding()]
param(
[string]$OSBuildNumberVersion
)
#Function Version 1.0
if($OSBuildNumberVersion -eq [string]::Empty -or $OSBuildNumberVersion -eq $null)
{
    Write-Verbose("Getting the local machine version build number")
    $OSBuildNumberVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
    Write-Verbose("Got {0} for the version build number" -f $OSBuildNumberVersion)
}
else 
{
    Write-Verbose("Passed - [string]OSBuildNumberVersion : {0}" -f $OSBuildNumberVersion)
}

$osReturnValue
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

Write-Verbose("Returned: {0}" -f $osReturnValue)
return $osReturnValue