Function Get-CuriousEventsFromPerformanceLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$LoadedPerfObject,
        [Parameter(Mandatory = $false)][object]$MultiThresholdConditionObject,
        [Parameter(Mandatory = $false)][string]$ExportDirectory,
        [Parameter(Mandatory = $false)][string]$SaveName,
        [Parameter(Mandatory = $false)][bool]$ReturnData = $true
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-VerboseWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-HostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/PerformanceData/Export-PerformanceDataToCSVFile/Export-PerformanceDataToCSVFile.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/PerformanceData/New-CounterDataObject/New-CounterDataObject.ps1
    #>
    <#
    [hashtable]LoadedPerfObject - return object from Load-PerformanceCounters:  https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1

    [object]MultiThresholdConditionObject - All conditions must be met for it to be a curious event
        [hashtable]MultiThresholdCondition- key counter path '\\ServerName\processor(_total)\% processor time'
                [double/int]Threshold
                [string]ThresholdType
        [int]CuriousTimeSpanInSeconds //How many seconds the conditions need to be met for it to be a curious timeframe event
        [int]ViewTimeSpanInSecondsBefore //How many seconds to collect datapoints before the curious timeframe
        [int]ViewTimeSpanInSecondsAfter //How many seconds to collect datapoints after the curious timeframe
    #>

    Add-Type -TypeDefinition @"

    namespace PerfCounterMonitorThreshold
    {
        public enum ThresholdType
        {
            Unknown,
            GreaterThan,
            GreaterThanOrEqual,
            LessThan,
            LessThanOrEqual
        }
    }

"@

    Function Test-ThresholdType {
        param(
            [Parameter(Mandatory = $true)][double]$CookedValue,
            [Parameter(Mandatory = $true)][string]$ThresholdType,
            [Parameter(Mandatory = $true)][double]$Threshold
        )
        switch ($ThresholdType) {
            ([PerfCounterMonitorThreshold.ThresholdType]::GreaterThan) { if ($CookedValue -gt $Threshold) { return $true } else { return $false } }
            ([PerfCounterMonitorThreshold.ThresholdType]::GreaterThanOrEqual) { if ($CookedValue -ge $Threshold) { return $true } else { return $false } }
            ([PerfCounterMonitorThreshold.ThresholdType]::LessThan) { if ($CookedValue -lt $Threshold) { return $true } else { return $false } }
            ([PerfCounterMonitorThreshold.ThresholdType]::LessThanOrEqual) { if ($CookedValue -le $Threshold) { return $true } else { return $false } }
        }
    }

    ########## Parameter Binding Exceptions ##############

    if ($ReturnData -eq $false -and [string]::IsNullOrEmpty($SaveName) -and [string]::IsNullOrEmpty($ExportDirectory)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide how to process the data. It needs to be returned or saved out. Use ReturnData or SaveName & ExportDirectory parameters to `
    accomplish this."
    }
    if ($ReturnData -eq $false -and [string]::IsNullOrEmpty($SaveName)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveName"
    }
    if ($ReturnData -eq $false -and ([string]::IsNullOrEmpty($ExportDirectory) -or (Test-Path $ExportDirectory))) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExportDirectory"
    }

    if ($null -eq $MultiThresholdConditionObject) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MultiThresholdConditionObject"
    }
    foreach ($key in $MultiThresholdConditionObject.MultiThresholdCondition.Keys) {
        if ([string]::IsNullOrEmpty($MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType) -or
            ($MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::GreaterThan -and
                $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::GreaterThanOrEqual -and
                $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::LessThan -and
                $MultiThresholdConditionObject.MultiThresholdCondition[$key].ThresholdType -ne [PerfCounterMonitorThreshold.ThresholdType]::LessThanOrEqual)) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ThresholdType property with a string value of 'GreaterThan', 'GreaterThanOrEqual', 'LessThan', or 'LessThanOrEqual'"
        }
        if ($null -eq $MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold -or
            ($MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold.GetType().Name -ne "Double" -and $MultiThresholdConditionObject.MultiThresholdCondition[$key].Threshold.GetType().Name -ne "Int32")) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a Threshold property with a Int32 or double type value."
        }
    }
    if ($null -eq $MultiThresholdConditionObject.CuriousTimeSpanInSeconds -or
        ($MultiThresholdConditionObject.CuriousTimeSpanInSeconds.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.CuriousTimeSpanInSeconds -lt 1)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a CuriousTimeSpanInSeconds property with a Int32 type value at a value of 1 or greater."
    }
    if ($null -eq $MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore -or
        ($MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore -lt 0)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ViewTimeSpanInSecondsBefore property with a Int32 type value at a value of 0 or greater."
    }
    if ($null -eq $MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter -or
        ($MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter.GetType().Name -ne "Int32" -and $MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter -lt 0)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Multi Threshold Condition Object. `
        Need to provide a ViewTimeSpanInSecondsAfter property with a Int32 type value at a value of 0 or greater."
    }

    $masterKeys = @()
    foreach ($key in $MultiThresholdConditionObject.MultiThresholdCondition.Keys) {
        $masterKeys += $key
    }

    $curiousEventsTimes = @()
    $mainKey = $masterKeys[0]
    $actualMulti = $masterKeys.Count -gt 1
    foreach ($datapoint in $LoadedPerfObject[$mainKey].GetData) {
        if ((Test-ThresholdType -CookedValue ($datapoint.CookedValue) `
                    -ThresholdType ($MultiThresholdConditionObject.MultiThresholdCondition[$mainKey].ThresholdType) `
                    -Threshold ($MultiThresholdConditionObject.MultiThresholdCondition[$mainKey].Threshold))) {
            $allTrue = $false
            $timeKey = $datapoint.TimeStamp
            if ($actualMulti) {
                $indexKey = 1
                $allTrue = $true #All Conditions must be true before we go to the next step
                while ($indexKey -lt $masterKeys.Count) {
                    $thisKey = $masterKeys[$indexKey++]
                    if (-not (Test-ThresholdType -CookedValue ($LoadedPerfObject[$thisKey].TimeHash[$timeKey].CookedValue) `
                                -ThresholdType ($MultiThresholdConditionObject.MultiThresholdCondition[$thisKey].ThresholdType) `
                                -Threshold ($MultiThresholdConditionObject.MultiThresholdCondition[$thisKey].Threshold))) {
                        $allTrue = $false
                        break
                    }
                }
            }

            if (($actualMulti -and $allTrue) -or ($actualMulti -eq $false)) {
                $curiousEventsTimes += $timeKey
            }
        }
    }

    #now loop through the times to find times that are within the threshold limit.
    $index = 0
    $alreadyAdded = [datetime]::MinValue
    $filteredCuriousEventsTimes = @()
    while ($index -lt $curiousEventsTimes.Count) {
        $currentTime = $curiousEventsTimes[$index]
        $nextTime = $curiousEventsTimes[$index + 1]
        $timeSpan = $nextTime - $currentTime
        if ($timeSpan.TotalSeconds -le $MultiThresholdConditionObject.CuriousTimeSpanInSeconds) {
            if ($currentTime -ne $alreadyAdded) {
                $filteredCuriousEventsTimes += $currentTime
            }
            $filteredCuriousEventsTimes += $nextTime
            $alreadyAdded = $nextTime
        }
        $index++
    }

    [System.Collections.Generic.List[System.Object]]$masterIssueList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    $startIssueIndex = 0
    $endIssueIndex = 1
    while ($endIssueIndex -lt $filteredCuriousEventsTimes.Count) {
        $singleIssue = @()
        $singleIssue += $filteredCuriousEventsTimes[$startIssueIndex]
        while ($endIssueIndex -lt $filteredCuriousEventsTimes.Count) {
            $currentTime = $filteredCuriousEventsTimes[$endIssueIndex]
            $singleIssue += $currentTime
            $nextTime = $filteredCuriousEventsTimes[$endIssueIndex + 1]
            $timeSpan = $nextTime - $currentTime
            if ($timeSpan.TotalSeconds -gt $MultiThresholdConditionObject.CuriousTimeSpanInSeconds) {
                $masterIssueList.Add($singleIssue)
                $startIssueIndex = ++$endIssueIndex
                $endIssueIndex++
                break;
            }
            $endIssueIndex++
        }
    }

    [System.Collections.Generic.List[System.Object]]$allIssuesDataPoints = New-Object -TypeName System.Collections.Generic.List[System.Object]
    foreach ($issue in $masterIssueList) {
        $startTime = $issue[0].AddSeconds(-$MultiThresholdConditionObject.ViewTimeSpanInSecondsBefore)
        $endTime = $issue[-1].AddSeconds($MultiThresholdConditionObject.ViewTimeSpanInSecondsAfter)
        $issueStartTime = $issue[0]
        $hashCounterPathKey = @{}

        foreach ($key in $LoadedPerfObject.Keys) {
            $counterDataPoints = @()
            foreach ($datapoint in $LoadedPerfObject[$key].GetData) {
                if ($datapoint.TimeStamp -ge $startTime -and $datapoint.TimeStamp -le $endTime) {
                    $counterDataPoints += $datapoint
                    continue;
                }
                if ($datapoint.TimeStamp -gt $endTime) {
                    break;
                }
            }
            $counterDataObject = New-CounterDataObject -PerformanceCounterSamples $counterDataPoints
            $hashCounterPathKey.Add($key, $counterDataObject)
        }

        $obj = New-Object -TypeName PSCustomObject
        $obj | Add-Member -MemberType NoteProperty -Name "StartOfIssue" -Value $issueStartTime
        $obj | Add-Member -MemberType NoteProperty -Name "HashData" -Value $hashCounterPathKey
        $allIssuesDataPoints.Add($obj)
    }

    if ($null -ne $ExportDirectory -and
        $null -ne $SaveName) {

        $saveLocation = "{0}\{1}_StartOfIssueTime_{2}.csv"
        foreach ($issueTime in $allIssuesDataPoints) {
            $savePath = $saveLocation -f $ExportDirectory, $SaveName, ($issueTime.StartOfIssue.ToString("yyyyMMddHHmmss"))
            Export-PerformanceDataToCSVFile -LoadedPerfObject $issueTime.HashData -FullSavePath $savePath
        }
    }

    if ($ReturnData) {
        return $allIssuesDataPoints
    }
}