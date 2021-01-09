Function Get-PerformanceThresholdCounters {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [string]$PerformanceCounter,
        [array]$Servers = @($env:COMPUTERNAME),
        [double]$AverageThreshold,
        [double]$MaxThreshold,
        [string]$ThresholdType,
        [System.Management.Automation.ActionPreference]$ActionPreference = "SilentlyContinue"
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-VerboseWriter.ps1
    #>
    <#
    TODO:
    - Add an instance filter option
    #>

    Write-VerboseWriter("Calling: Get-PerformanceThresholdCounters")
    Write-VerboseWriter("Passed: [string]PerformanceCounter: {0} | [double]AverageThreshold: {1} | [double]MaxThreshold: {2} | [string]ThresholdType: {3} | [ActionPreference]ActionPreference: {4}" -f `
            $PerformanceCounter,
        $AverageThreshold,
        $MaxThreshold,
        $ThresholdType,
        $ActionPreference)
    Function Get-PerformanceThresholdCounterObject {
        $obj = New-Object PSCustomObject
        $obj | Add-Member -MemberType NoteProperty -Name "AverageThreshold" -Value $AverageThreshold
        $obj | Add-Member -MemberType NoteProperty -Name "MaxThreshold" -Value $MaxThreshold
        $obj | Add-Member -MemberType NoteProperty -Name "ThresholdType" -Value $ThresholdType
        return $obj
    }

    ########## Parameter Binding Exceptions ##############
    if ([string]::IsNullOrEmpty($PerformanceCounter) -or
        $PerformanceCounter.StartsWith("\")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounter. Can not be null or empty and must not start with a '\'."
    }
    if ([string]::IsNullOrEmpty($ThresholdType) -or (
            $ThresholdType -ne "LessThan" -and
            $ThresholdType -ne "GreaterThan")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ThresholdType. Accepted values are LessThan and GreaterThan."
    }

    try {
        [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-VerboseWriter("Getting the counters....")
        $counterSamples = (Get-Counter -ComputerName $Servers -Counter $PerformanceCounter -ErrorAction $ActionPreference ).CounterSamples
        if ($counterSamples.Count -eq 0) {
            throw "Failed to return any counters..."
        }
        Write-VerboseWriter("Finished getting the counters. Took {0} seconds to complete." -f ($stopWatch.Elapsed.TotalSeconds))
    } catch {
        $throwString = "Failed to run Get-Counter without any error. Error: '{0}'" -f ($Error[0].Exception)
        throw  $throwString
    }

    $returnHash = @{}
    $currentSeconds = $stopWatch.Elapsed.TotalSeconds
    $counterPaths = ($counterSamples | Group-Object Path).Name
    Write-VerboseWriter("Took {0} seconds to group the counter paths." -f ($stopWatch.Elapsed.TotalSeconds - $currentSeconds))
    $currentSeconds = $stopWatch.Elapsed.TotalSeconds
    foreach ($path in $counterPaths) {
        $returnHash.Add($path, (Get-PerformanceThresholdCounterObject))
    }
    $writeString = "Took {0} seconds to add {1} paths to the hash table." -f ($stopWatch.Elapsed.TotalSeconds - $currentSeconds), ($counterPaths.Count)
    Write-VerboseWriter($writeString)
    Write-VerboseWriter("Took {0} seconds to complete the Get-PerformanceThresholdCounters function" -f ($stopWatch.Elapsed.TotalSeconds))

    return $returnHash
}