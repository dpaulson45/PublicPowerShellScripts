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

Describe "Testing Get-ServerType" {

    Context "Good Test Results" {
        It "Physical" {
            $results = Get-ServerType -ServerType "Physical"
            $results | Should Be "Physical"
        }
        It "HyperV" {
            $results = Get-ServerType -ServerType "Microsoft Corporation"
            $results | Should Be "HyperV"
        }
        It "VMware" {
            $results = Get-ServerType -ServerType "VMware"
            $results | Should Be "VMware"
        }
    }
}