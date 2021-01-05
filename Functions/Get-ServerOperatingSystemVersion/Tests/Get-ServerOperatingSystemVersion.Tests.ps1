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

Describe "Testing Get-ServerOperatingSystemVersion" {

    Context "Good Testing Results" {
        It "Windows 2008" {
            Get-ServerOperatingSystemVersion "6.0.6000" | Should Be Windows2008
        }
        It "Windows 2008 R2 v1" {
            Get-ServerOperatingSystemVersion "6.1.7600" | Should Be Windows2008R2
        }
        It "Windows 2008 R2 v2" {
            Get-ServerOperatingSystemVersion "6.1.7601" | Should Be Windows2008R2
        }
        It "Windows 2012" {
            Get-ServerOperatingSystemVersion "6.2.9200" | Should Be Windows2012
        }
        It "Windows 2012 R2" {
            Get-ServerOperatingSystemVersion "6.3.9600" | Should Be Windows2012R2
        }
        It "Windows 2016" {
            Get-ServerOperatingSystemVersion "10.0.14393" | Should Be Windows2016
        }
        It "Windows 2019" {
            Get-ServerOperatingSystemVersion "10.0.17713" | Should be Windows2019
        }
    }
    Context "Bad Testing Results" {
        It "Default" {
            Get-ServerOperatingSystemVersion "10.0.143" | Should Be Unknown
        }
        It "Null - Local OS" {
            Get-ServerOperatingSystemVersion "" | Should Be Unknown
        }
    }
}