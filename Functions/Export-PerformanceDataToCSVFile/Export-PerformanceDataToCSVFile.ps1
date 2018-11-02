Function Export-PerformanceDataToCSVFile {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$LoadedPerfObject,
[Parameter(Mandatory=$true)][string]$FullSavePath
)

#Function Version 1.1
#[hashtable]LoadedPerfObject - return object from Load-PerformanceCounters:  https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}

########## Parameter Binding Exceptions ##############
if(Test-Path $FullSavePath)
{
    $throwString = "This file already exists '{0}'" -f $FullSavePath
    throw [System.Management.Automation.ParameterBindingException] $throwString
}

$firstKey = ($LoadedPerfObject.GetEnumerator() | Select-Object -First 1).Name
$masterCount = $LoadedPerfObject[$firstKey].AllData.Count 
[System.Collections.Generic.List[System.Object]]$timeList = New-Object -TypeName System.Collections.Generic.List[System.Object]
$index = 0
while($index -lt $masterCount)
{
    $addTimer = $true 
    $timeFrameObject = New-Object pscustomobject 

    foreach($key in $LoadedPerfObject.Keys)
    {
        if($addTimer)
        {
            $timeFrameObject | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value ($LoadedPerfObject[$key].AllData[$index].TimeStamp)
            $addTimer = $false 
        }
        $timeFrameObject | Add-Member -MemberType NoteProperty -Name $key -Value ($LoadedPerfObject[$key].AllData[$index].CookedValue)
    }
    $timeList.Add($timeFrameObject)
    $index++
}

$timeList | Export-Csv $FullSavePath
}