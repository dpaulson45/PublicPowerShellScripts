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

$dataLocation = "{0}\ProcessorWmiObjects" -f (Split-Path -Parent $MyInvocation.MyCommand.Path)

Describe "Testing Get-ProcessorInformation" {
    Context "Testing Local Collection" {
        $local = Get-ProcessorInformation -MachineName $env:COMPUTERNAME
        It "Local Test" {
            $local.ProcessorClassObject | Should Not Be $null
        }
    }
    Context "Mock Data Testing - Single Processor" {
        Mock Get-WmiObjectHandler { return (Import-Clixml ("{0}\SingleProcessor.xml" -f $dataLocation)) }
        Mock Invoke-ScriptBlockHandler { return 8 }
        $results = Get-ProcessorInformation -MachineName $env:COMPUTERNAME
        It "Name" {
            $results.Name | Should Be "Intel(R) Core(TM) i7-6820HQ CPU @ 2.70GHz"
        }
        It "MaxMegacyclesPerCore" {
            $results.MaxMegacyclesPerCore | Should Be 2701
        }
        It "NumberOfPhysicalCores" {
            $results.NumberOfPhysicalCores | Should Be 4
        }
        It "NumberOfLogicalCores" {
            $results.NumberOfLogicalCores | Should Be 8
        }
        It "NumberOfProcessors" {
            $results.NumberOfProcessors | Should Be 1
        }
        It "CurrentMegacyclesPerCore" {
            $results.CurrentMegacyclesPerCore | Should Be 0
        }
        It "ProcessorIsThrottled" {
            $results.ProcessorIsThrottled | Should Be $false
        }
        It "DifferentProcessorsDetected" {
            $results.DifferentProcessorsDetected | Should Be $false
        }
        It "DifferentProcessorCoreCountDetected" {
            $results.DifferentProcessorCoreCountDetected | Should Be $false
        }
        It "EnvironmentProcessorCount" {
            $results.EnvironmentProcessorCount | Should Be 8
        }
        It "ProcessorClassObject" {
            $results.ProcessorClassObject | Should Not Be $null
        }
    }

    Context "Mock Data Testing - DifferentProcessorsDetected" {
        Mock Get-WmiObjectHandler { return (Import-Clixml ("{0}\DifferentProcessorsDetected.xml" -f $dataLocation)) }
        Mock Invoke-ScriptBlockHandler { return 19 }
        $results = Get-ProcessorInformation -MachineName $env:COMPUTERNAME
        It "ProcessorIsThrottled" {
            $results.ProcessorIsThrottled | Should Be $false
        }
        It "DifferentProcessorsDetected" {
            $results.DifferentProcessorsDetected | Should Be $true
        }
        It "DifferentProcessorCoreCountDetected" {
            $results.DifferentProcessorCoreCountDetected | Should Be $true
        }
        It "NumberOfProcessors" {
            $results.NumberOfProcessors | Should Be 2
        }
    }
}