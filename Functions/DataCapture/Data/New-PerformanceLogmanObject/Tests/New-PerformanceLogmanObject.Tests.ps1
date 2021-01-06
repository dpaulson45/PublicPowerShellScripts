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
$outputLocation = "{0}\{1}" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), "PesterTests.Ignore"
if (!(Test-Path $outputLocation)) {
    New-Item $outputLocation -ItemType Directory | Out-Null
}
$counters = @("\Processor(*)\*", "\Process(*)\*")
$name = "PesterTesting"

Describe "Testing New-PerformanceLogmanObject" {

    Context "Good Test Results" {
        $perfObject = New-PerformanceLogmanObject -ServerList $env:COMPUTERNAME -PerformanceLogmanName $name -PerformanceCounters $counters -SavePath $outputLocation -VerboseEnabled $true
        It "Deleting Logman before creation" {
            $perfObject.DeleteLogman() | Should Be "Failed"
        }
        It "Creating Logman" {
            $perfObject.CreateLogman() | Should Be "Success"
        }
        It "Starting Logman" {
            $perfObject.StartLogman() | Should Be "Success"
        }
        Start-Sleep 5
        It "Stopping Logman" {
            $perfObject.StopLogman() | Should Be "Success"
        }
        It "Deleting Logman" {
            $perfObject.DeleteLogman() | Should Be "Success"
        }
    }
}