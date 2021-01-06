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
#Should add more, but this should do for now.
Describe "Testing Get-TimeZoneInformationRegistrySettings" {
    $results = Get-TimeZoneInformationRegistrySettings -MachineName $env:COMPUTERNAME

    It "Returned an object" {
        $results | Should not be $null
    }

    It "DynamicDaylightTimeDisabled is 0" {
        $results.DynamicDaylightTimeDisabled | Should be 0
    }

    It "TimeZoneKeyName not null" {
        $results.TimeZoneKeyName | Should not be $null
    }
}