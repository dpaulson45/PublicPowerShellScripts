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

Describe "Testing Invoke-RegistryGetValue" {

    Context "Good Test Results" {
        It "Windows Directory" {
            Invoke-RegistryGetValue -MachineName $env:COMPUTERNAME -SubKey "SYSTEM\CurrentControlSet\Control\Windows" -GetValue "Directory" | Should Be C:\WINDOWS
        }
        It "Missing key" {
            Invoke-RegistryGetValue -MachineName $env:COMPUTERNAME -SubKey "SYSTEM\CurrentControlSet\Control\Windows" -GetValue "Blah" | Should Be $null
        }
        It "Catch Action" {
            Invoke-RegistryGetValue -MachineName $env:COMPUTERNAME -SubKey "SYSTEM\CurrentControlSet\Control\BadValueKey" -GetValue "Blah" -CatchActionFunction  ([scriptblock]::Create('Set-Variable -Name "TestCatch" -Value "TestCatch" -Scope Script'))
            $Script:TestCatch | Should Be "TestCatch"
        }
    }
}