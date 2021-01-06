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
$provider = "Microsoft-Windows-LDAP-Client 0x1a59afa3 0xff"
$name = "PesterTesting"

Describe "Testing New-TraceLogmanObject" {

    Context "Good Test Results" {
        $traceLogman = New-TraceLogmanObject -TraceLogmanName $name -SaveFileDirectory $outputLocation -Provider $provider -Servers $env:COMPUTERNAME -OverwriteExistingFile $false -VerboseEnabled $true
        It "Creating Logman" {
            $traceLogman.CreateLogman() | Should Be "Success"
        }
        It "Deleting Logman - ETS enabled" {
            $traceLogman.DeleteLogman() | Should Be "Success"
        }
        It "Starting Logman - ETS enabled" {
            $traceLogman.StartLogman() | Should Be "Success"
        }
        Start-Sleep 5
        It "Stopping Logman - ETS enabled" {
            $traceLogman.StopLogman() | Should Be "Success"
        }
        It "Deleting Logman after stop - ETS Enabled" {
            $traceLogman.DeleteLogman() | Should Be "Success"
        }
    }
}