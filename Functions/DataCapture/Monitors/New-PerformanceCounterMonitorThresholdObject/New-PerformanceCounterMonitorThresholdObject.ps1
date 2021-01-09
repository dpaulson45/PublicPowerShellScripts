Function New-PerformanceCounterMonitorThresholdObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Bug')]
    [CmdletBinding()]
    param(
        [hashtable]$PerformanceThresholdCounters,
        [int]$SampleInterval = 1,
        [int]$MaxSamples = 10,
        [int]$SleepInSeconds = 0,
        [int]$UpdateEveryXMinutes = 5,
        [bool]$IncludeDateTimeOnUpdate = $true,
        [object]$LoggerObject,
        [scriptblock]$HostFunctionCaller,
        [scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>
    <#
    This works remotely as well
    [hashtable]$PerformanceThresholdCounters
        [Key = \\serverName\logicaldisk(c:)\avg. disk sec/write]
            [value]
                [double]AverageThreshold
                [double]MaxThreshold
                [string]ThresholdType - GreaterThan/LessThan
    #>

    if ($SampleInterval -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SampleInterval. Provide a value greater than 1."
    }
    if ($MaxSamples -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSamples. Provide a value greater than 1."
    }
    if ($UpdateEveryXMinutes -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid UpdateEveryXMinutes. Provide a value greater than 1"
    }

    if ($null -eq $PerformanceThresholdCounters -or
        $PerformanceThresholdCounters.Count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters."
    }

    foreach ($key in $PerformanceThresholdCounters.Keys) {
        try {
            Get-Counter -Counter $key -ErrorAction stop | Out-Null
        } catch {
            $info = "Failed to provide valid key '{0}'. Error: {1}" -f $key, ($Error[0].Exception)
            throw [System.Management.Automation.ParameterBindingException] $info
        }
        if ([string]::IsNullOrEmpty($PerformanceThresholdCounters[$key].ThresholdType) -or
            ($PerformanceThresholdCounters[$key].ThresholdType -ne "GreaterThan" -and
                $PerformanceThresholdCounters[$key].ThresholdType -ne "LessThan")) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a ThresholdType property with a string value of 'GreaterThan' or 'LessThan'"
        }
        if ($null -eq $PerformanceThresholdCounters[$key].AverageThreshold -or
            $PerformanceThresholdCounters[$key].AverageThreshold.GetType().Name -ne "Double") {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a AverageThreshold property with a double type value."
        }
        if ($null -eq $PerformanceThresholdCounters[$key].MaxThreshold -or
            $PerformanceThresholdCounters[$key].MaxThreshold.GetType().Name -ne "Double") {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a MaxThreshold property with a double type value."
        }
    }

    Add-Type -TypeDefinition @"
    namespace PerformanceCounterMonitorThreshold
    {
        public enum StatusCode
        {
            None,
            Passed,
            ThresholdMet
        }
    }
"@

    Function Get-Counters {
        [CmdletBinding()]
        [OutputType([System.Collections.Generic.List[System.Object]])]

        [System.Collections.Generic.List[System.Object]]$counterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
        foreach ($key in $PerformanceThresholdCounters.Keys) {
            $counterList.Add($key)
        }

        return $counterList
    }

    Function Get-ThresholdMetObjectDetails {
        $obj = New-Object PSCustomObject
        $obj | Add-Member -MemberType NoteProperty -Name "Counter" -Value ([string]::Empty)
        $obj | Add-Member -MemberType NoteProperty -Name "MetValue" -Value ([double]0)
        $obj | Add-Member -MemberType NoteProperty -Name "Details" -Value ([string]::Empty)
        $obj | Add-Member -MemberType NoteProperty -Name "Type" -Value ([string]::Empty)
        return $obj
    }

    $perfMonitorObject = New-Object PSCustomObject

    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "PerformanceThresholdCounters" -Value $PerformanceThresholdCounters
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "MaxSamples" -Value $MaxSamples
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepInSeconds" -Value $SleepInSeconds
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "Counters" -Value (Get-Counters)
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "IncludeDateTimeOnUpdate" $IncludeDateTimeOnUpdate
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetDetails" -Value ([string]::Empty)
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetObjectDetails" -Value (Get-ThresholdMetObjectDetails)
    $perfMonitorObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

    if ($null -ne $HostFunctionCaller) {
        $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    #Master Template https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-PerformanceCounterMinMaxAverageCorrectly/Get-PerformanceCounterMinMaxAverageCorrectly.ps1
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetPerformanceCounterMinMaxAverageCorrectly" -Value {

        [CmdletBinding()]
        param(
            [object]$PerformanceCounterSamples
        )

        <#
        Calculate Averages
        Average calculation for Average counters taken from these references:
        https://msdn.microsoft.com/en-us/library/ms804010.aspx
        https://blogs.msdn.microsoft.com/ntdebugging/2013/09/30/performance-monitor-averages-the-right-way-and-the-wrong-way/

        [arrayOrList]PerformanceCounterSamples
            CookedValue
            RawValue
            TimeBase
            SecondValue
            CounterType
        #>

        #Function Version 1.0
        if ($null -eq $PerformanceCounterSamples -or
            $PerformanceCounterSamples.Count -le 1) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounterSamples. Provide more than 1 sample as well."
        }

        $min = [int64]::MaxValue
        $max = [int64]::MinValue

        foreach ($sample in $PerformanceCounterSamples) {
            if ($sample.CookedValue -lt $min) { $min = $sample.CookedValue }
            if ($sample.CookedValue -gt $max) { $max = $sample.CookedValue }
        }

        if ($PerformanceCounterSamples[0].CounterType -like "AverageTimer*") {
            $numTicksDiff = $PerformanceCounterSamples[-1].RawValue - $PerformanceCounterSamples[0].RawValue
            $frequency = $PerformanceCounterSamples[-1].TimeBase
            $numOpsDif = $PerformanceCounterSamples[-1].SecondValue
            if ($frequency -ne 0 -and $numTicksDiff -ne 0 -and $numOpsDif -ne 0) {
                $avg = (($numTicksDiff / $frequency) / $numOpsDif)
            } else {
                $avg = 0
            }
        } else {
            $avg = ($PerformanceCounterSamples | Measure-Object -Property CookedValue -Average).Average
        }

        $minMaxAvgObj = New-Object PSCustomObject

        $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Min" -Value $min
        $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Max" -Value $max
        $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Avg" -Value $avg

        return $minMaxAvgObj
    }

    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {

        if ([DateTime]::Now -gt $this.NextUpdateTime) {
            [DateTime]$dt = [DateTime]::Now
            if ($this.IncludeDateTimeOnUpdate) {
                $this.WriteHostWriter("[{0}] : Everything is passing checks thus far..." -f $dt)
            } else {
                $this.WriteHostWriter("Everything is passing checks thus far...")
            }
            $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
        }
    }

    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetData" -Value {
        $measure = Measure-Command { $results = (Get-Counter -Counter $this.Counters -SampleInterval $this.SampleInterval -MaxSamples $this.MaxSamples).CounterSamples | Group-Object Path }
        $this.WriteVerboseWriter("Took {0} seconds to get the data" -f $measure.TotalSeconds)
        return $results
    }

    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetMonitorResults" -Value {

        $results = $this.GetData()
        foreach ($counterResults in $results) {
            $counterName = $counterResults.Name
            $counterPassedObj = $this.PerformanceThresholdCounters[$counterName]
            $minMaxAvgResults = $this.GetPerformanceCounterMinMaxAverageCorrectly($counterResults.Group)

            $thresholdType = ([string]::Empty)
            $thresholdValue = 0

            if ($counterPassedObj.ThresholdType -eq "GreaterThan") {
                if ($minMaxAvgResults.Max -ge $counterPassedObj.MaxThreshold) {
                    $details = "Met max spike threshold. Current max spike is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Max, $counterPassedObj.MaxThreshold, $counterName
                    $thresholdType = "GreaterThanMax"
                    $thresholdValue = $minMaxAvgResults.Max
                    $thresholdMet = $true
                }
                if ($minMaxAvgResults.Avg -ge $counterPassedObj.AverageThreshold) {
                    $details = "Met average threshold. Current average is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                    $thresholdType = "GreaterThanAvg"
                    $thresholdValue = $minMaxAvgResults.Avg
                    $thresholdMet = $true
                }
            } elseif ($counterPassedObj.ThresholdType -eq "LessThan") {
                if ($minMaxAvgResults.Min -le $counterPassedObj.MaxThreshold) {
                    $details = "Met min dip threshold. Current min dip is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Min, $counterPassedObj.MaxThreshold, $counterName
                    $thresholdType = "LessThanMin"
                    $thresholdValue = $minMaxAvgResults.Min
                    $thresholdMet = $true
                }
                if ($minMaxAvgResults.Avg -le $counterPassedObj.AverageThreshold) {
                    $details = "Met average threshold. Current average is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                    $thresholdType = "LessThanAvg"
                    $thresholdValue = $minMaxAvgResults.Avg
                    $thresholdMet = $true
                }
            }
            if ($thresholdMet) {
                $this.ThresholdMetDetails = $details
                $this.ThresholdMetObjectDetails.Counter = $counterName
                $this.ThresholdMetObjectDetails.MetValue = $thresholdValue
                $this.ThresholdMetObjectDetails.Details = $details
                $this.ThresholdMetObjectDetails.Type = $thresholdType
                $this.WriteHostWriter($details)
                return [PerformanceCounterMonitorThreshold.StatusCode]::ThresholdMet
            }
        }
        $this.WriteUpdate()
        Start-Sleep $this.SleepInSeconds
        return [PerformanceCounterMonitorThreshold.StatusCode]::Passed
    }

    return $perfMonitorObject
}