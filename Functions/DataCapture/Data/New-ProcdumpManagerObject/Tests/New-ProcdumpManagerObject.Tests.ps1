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

$procdumpLocation = "{0}\{1}\procdump.exe" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), "PesterTests.Ignore"
$dumpFolder = $procdumpLocation.Replace("procdump.exe", "")
$items = Get-ChildItem $dumpFolder | Where-Object { $_.Name -like "*.dmp" }
foreach ($item in $items) {
    Remove-Item $item -Force
}
if (!(Test-Path $procdumpLocation)) {
    throw "failed to provide valid path to procdump location"
    exit
}
$processName = "explorer.exe"
$badProcessName = "badName"

Describe "Testing New-ProcdumpManagerObject" {

    Context "Good Test Results" {
        $procdumpObject = New-ProcdumpManagerObject -BinaryProcdumpExe $procdumpLocation -DumpFolder $dumpFolder -ProcessName $processName -Servers $env:COMPUTERNAME -SecondsWait 3
        It "Testing ValidateProcessOnServer" {
            $procdumpObject.ValidateProcessOnServer() | Should Be $true
        }
        It "Testing Dump" {
            $dumpResults = $procdumpObject.DumpOnServer($env:COMPUTERNAME)
            $dumpResults[-2].Contains("Dump count reached.") | Should Be $true
        }
    }
    Context "Bad Test Results" {
        $procdumpObject = New-ProcdumpManagerObject -BinaryProcdumpExe $procdumpLocation -DumpFolder $dumpFolder -ProcessName $badProcessName -Servers $env:COMPUTERNAME -SecondsWait 3
        It "Testing Bad ValidateProcessOnServer" {
            $procdumpObject.ValidateProcessOnServer() | Should Be $false
        }
    }
}