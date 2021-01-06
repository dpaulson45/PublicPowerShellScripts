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

$dataLocation = "{0}\ExchangeAdminDisplayVersionTestData" -f (Split-Path -Parent $MyInvocation.MyCommand.Path)
$baseName = "Exchange{0}AdminDisplayVersion"

$versionList = @("2010", "2013", "2016", "2019")


Describe "Testing Get-ExchangeMajorVersion" {
    foreach ($version in $versionList) {
        Context ("Testing Exchange {0}" -f $version) {
            $xml = Import-Clixml ("{0}\{1}.xml" -f $dataLocation, ($baseName -f $version))
            $txt = Get-Content ("{0}\{1}String.dat" -f $dataLocation, ($baseName -f $version))
            It ("{0} Object" -f $version) {
                Get-ExchangeMajorVersion -AdminDisplayVersion $xml | Should Be ("Exchange{0}" -f $version)
            }
            It ("{0} String" -f $version) {
                Get-ExchangeMajorVersion -AdminDisplayVersion $txt | Should Be ("Exchange{0}" -f $version)
            }
        }
    }

    Context "Unknown Result" {
        It "Unknown" {
            Get-ExchangeMajorVersion -AdminDisplayVersion "8.00.389" | Should Be "Unknown"
        }
    }
}