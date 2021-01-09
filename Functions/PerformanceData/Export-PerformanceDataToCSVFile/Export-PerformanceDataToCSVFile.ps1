Function Export-PerformanceDataToCSVFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$LoadedPerfObject,
        [Parameter(Mandatory = $true)][string]$FullSavePath
    )
    #[hashtable]LoadedPerfObject - return object from Load-PerformanceCounters:  https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1

    if (Test-Path $FullSavePath) {
        $throwString = "This file already exists '{0}'" -f $FullSavePath
        throw [System.Management.Automation.ParameterBindingException] $throwString
    }

    $firstKey = ($LoadedPerfObject.GetEnumerator() | Select-Object -First 1).Name
    $masterCount = $LoadedPerfObject[$firstKey].AllData.Count
    [System.Collections.Generic.List[System.Object]]$timeList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    $index = 0
    while ($index -lt $masterCount) {
        $addTimer = $true
        $timeFrameObject = New-Object PSCustomObject

        foreach ($key in $LoadedPerfObject.Keys) {
            if ($addTimer) {
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