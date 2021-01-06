[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWMICmdlet', '', Justification = 'This is what this function is for')]
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

Describe "Testing Get-WmiObjectHandler" {
    Context "Good Test Results" {
        It "Win32_OperatingSystem" {
            $osResults = Get-WmiObjectHandler -Class "Win32_OperatingSystem" -Verbose
            $osResults.PSComputerName | Should Be $env:COMPUTERNAME
        }
        It "Bad Class" {
            Get-WmiObjectHandler -Class "Bad Class" | Should Be $null
        }
        It "Catch Action" {
            Get-WmiObjectHandler -Class "Bad Class" -Verbose -CatchActionFunction ([scriptblock]::Create('Set-Variable -Name "TestCatch" -Value "TestCatch" -Scope Script'))
            $Script:TestCatch | Should Be "TestCatch"
        }
        It "Testing Filter" {
            [array]$networkAdapter = Get-WmiObject -Class Win32_NetworkAdapter -Filter "NetConnectionStatus ='2'"
            $networkAdapter[0].NetConnectionStatus | Should Be 2
        }
    }
}