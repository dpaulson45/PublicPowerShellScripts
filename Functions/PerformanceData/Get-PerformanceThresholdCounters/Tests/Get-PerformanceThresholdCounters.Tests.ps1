[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Testing')]
[CmdletBinding()]
param()

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$here = $here.Replace("\Tests", "")
. "$here\$sut"

#Load Required Functions

$content = Get-Content "$here\$sut"
$foundRequiredFunctions = $false
foreach ($line in $content) {
    if ($foundRequiredFunctions) {
        if ($line.Contains("#>")) {
            break
        }
        $webRequest = Invoke-WebRequest $line.Trim()
        if ($null -ne $webRequest -and
            $webRequest.Content) {
            Invoke-Expression $webRequest.Content
        }
    }
    if ($line.Contains("Required Functions:")) {
        $foundRequiredFunctions = $true
        continue
    }
}

$counter = "LogicalDisk(*)\*"
$thresholdTypes = @("GreaterThan", "LessThan")
$badThresholdTypes = @("GreaterThanOrEqualTo", "LessThanOrEqualTo")
$badCounter = "Blah\Counter"

Describe "Testing Get-PerformanceThresholdCounters" {
    Context "Good Tests Results" {
        $performanceThreshold = Get-PerformanceThresholdCounters -PerformanceCounter $counter -ThresholdType $thresholdTypes[0]
        It "Testing Type" {
            $performanceThreshold.GetType().Name | Should Be "HashTable"
        }
        It "Testing Name and Counter" {
            $testingName = "\\{0}\{1}(" -f ($env:COMPUTERNAME), ($counter.Substring(0, $counter.IndexOf("(")))
            foreach ($key in $performanceThreshold.Keys) {
                $key.ToLower().StartsWith($testingName.ToLower()) | Should Be "True"
            }
        }
    }
    Context "Throws" {
        It "Bad Threshold Type" {
            { Get-PerformanceThresholdCounters -PerformanceCounter $counter -ThresholdType $badThresholdTypes[0] } | Should -Throw `
                "Failed to provide valid ThresholdType. Accepted values are LessThan and GreaterThan."
        }
        It "Bad Passed Counter Name" {
            { Get-PerformanceThresholdCounters -PerformanceCounter ("\{0}" -f $counter) -ThresholdType $thresholdTypes[0] } | Should -Throw `
                "Failed to provide valid PerformanceCounter. Can not be null or empty and must not start with a '\'."
        }
        It "Bad Counter on Get-Counter - Error Action SilentlyContinue" {
            { Get-PerformanceThresholdCounters -PerformanceCounter $badCounter -ThresholdType $thresholdTypes[0] } | Should -Throw "Failed to return any counters..."
        }
        It "Bad Counter on Get-Counter - Error Action Stop" {
            { Get-PerformanceThresholdCounters -PerformanceCounter $badCounter -ThresholdType $thresholdTypes[0] -ActionPreference "Stop" } | Should -Throw `
                "Failed to run Get-Counter without any error. Error"
        }
    }
}