Function Get-PerformanceCounterMinMaxAverageCorrectly {
    [CmdletBinding()]
    param(
        [object]$PerformanceCounterSamples
    )
    <#
    Calculate Averages
    Average calculation for Average counters taken from these references:
    https://msdn.microsoft.com/en-us/library/ms804010.aspx
    https://blogs.msdn.microsoft.com/ntdebugging/2013/09/30/performance-monitor-averages-the-right-way-and-the-wrong-way/

[arrayorlist]PerformanceCounterSamples
    CookedValue
    RawValue
    TimeBase
    SecondValue
    CounterType
#>

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

    $minMaxAvgObj = New-Object pscustomobject

    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Min" -Value $min
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Max" -Value $max
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Avg" -Value $avg

    return $minMaxAvgObj
}