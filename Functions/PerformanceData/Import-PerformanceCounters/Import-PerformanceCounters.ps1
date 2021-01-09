Function Import-PerformanceCounters {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Bug inside of PSScriptAnalyzer')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$FilePaths,
        [Parameter(Mandatory = $false)][Int64]$MaxSample = [Int64]::MaxValue,
        [Parameter(Mandatory = $false)][datetime]$StartTime = [datetime]::MinValue,
        [Parameter(Mandatory = $false)][datetime]$EndTime = [datetime]::MaxValue,
        [Parameter(Mandatory = $false)][array]$Counters
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-VerboseWriter.ps1
    #>
    #If Load-PerformanceCounters isn't issued within the script, must use the schema from: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/AddTypeSchema/LoadPerformanceCounters_Schema.ps1
    <#
    When passing something like \\*\Process(*)\* we see a dramatic decrease in performance of reading the file. In a 1 GB file we see a decrease of performance by a few minutes vs providing all the values for the counters in Process
    For example: "\\*\Process(*)\% Privileged Time","\\*\Process(*)\% Processor Time","\\*\Process(*)\% User Time","\\*\Process(*)\Creating Process ID",..... so on
#>

    Function Get-FastCounterNames {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [Parameter(Mandatory = $true)][array]$Counters
        )
        Write-VerboseWriter("Getting the Counter Names vs using wild card as this has better performance")
        [System.Collections.Generic.List[System.Object]]$masterCounterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
        $findFastTrackCounters = @()
        foreach ($counter in $Counters) {
            if (!($counter.EndsWith("\*"))) {
                $masterCounterList.Add($counter)
            } else {
                $findFastTrackCounters += $counter
            }
        }
        if ($null -eq $findFastTrackCounters -or
            $findFastTrackCounters.Count -eq 0) {
            Write-VerboseWriter("All counters in the list are already optimized.")
            return $masterCounterList
        }
        [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $myParmas = @{
            Path        = $Path
            StartTime   = $StartTime
            EndTime     = $EndTime
            MaxSample   = 2
            ErrorAction = "SilentlyContinue"
            Verbose     = $false
            Counter     = $findFastTrackCounters
        }

        $measureImport = Measure-Command { $results = (Import-Counter @myParmas).CounterSamples }
        Write-VerboseWriter("Took {0} seconds to import" -f $measureImport.TotalSeconds)

        $measureGroup = Measure-Command { $groupResults = [LoadPerformanceCounters.PerformanceCounters]::GroupPerformanceCounterSamplesByPath($results) }
        Write-VerboseWriter("Took {0} seconds to group the results" -f $measureGroup.TotalSeconds)

        foreach ($key in $groupResults.Keys) {
            $inList = $false
            $counterGroup = $groupResults[$key][0]
            $counterName = $counterGroup.Path
            foreach ($counterCheck in $masterCounterList) {
                if ($counterName -like $counterCheck) {
                    $inList = $true
                    break;
                }
            }
            if ($inList) {
                continue
            }
            $counterNameObj = [LoadPerformanceCounters.PerformanceCounterName]::GetPerformanceCounterNameFromFullName($counterName, $counterGroup.InstanceName)
            if ([string]::IsNullOrEmpty($counterNameObj.InstanceName)) {
                $addCounter = "\\*\{0}\{1}"
            } else {
                $addCounter = "\\*\{0}(*)\{1}"
            }
            $addCounter = $addCounter -f $counterNameObj.ObjectName, $counterNameObj.CounterName
            $masterCounterList.Add($addCounter)
        }
        $stopWatch.Stop()
        Write-VerboseWriter("Finished getting the counter list in {0} seconds" -f $stopWatch.Elapsed.TotalSeconds)
        return $masterCounterList
    }

    ########## Parameter Binding Exceptions ##############

    foreach ($filePath in $FilePaths) {
        if (!(Test-Path $filePath)) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FilePaths"
        }
    }
    if ($null -eq $StartTime) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid StartTime"
    }
    if ($null -eq $EndTime) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EndTime"
    }
    if ($null -eq $MaxSample) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSample"
    }

    $params = @{
        Path        = $FilePaths
        StartTime   = $StartTime
        EndTime     = $EndTime
        MaxSample   = $MaxSample
        ErrorAction = "SilentlyContinue"
        Verbose     = $false
    }

    if ($null -ne $Counters -and
        $Counters.count -gt 0) {
        $fastCounters = Get-FastCounterNames -Path ($FilePaths[0]) -Counters $Counters
        $params.Add("Counter", $fastCounters)
    }

    $totalSize = 0
    Write-VerboseWriter("Importing files from batch list")
    foreach ($file in $filePaths) {
        Write-VerboseWriter("File Size {0}MB. File Name: {1}." -f ($size = (Get-Item $file).Length / 1MB), $file )
        $totalSize += $size
    }
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $importCounters = (Import-Counter @params).CounterSamples
    Write-VerboseWriter("Took {0} seconds to import this batch size of {1}MB for {2} datapoints." -f $stopWatch.Elapsed.TotalSeconds, $totalSize, $importCounters.count)
    return $importCounters
}