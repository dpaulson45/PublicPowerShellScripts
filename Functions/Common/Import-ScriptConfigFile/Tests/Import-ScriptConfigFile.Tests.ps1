[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Testing')]
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

$testingFile = "{0}\Tests\TestingConditions.config" -f $here
Write-Host("Testing file: {0}" -f $testingFile)
Import-ScriptConfigFile -ScriptConfigFileLocation $testingFile
Describe "Testing Import-ScriptConfigFile" {

    Context "Testing Results" {

        It "Testing ExtraTraceConfigFileContent not null" {
            $ExtraTraceConfigFileContent | Should not be $null
        }
        It "Testing ExtraTraceConfigFileContent Count" {
            $ExtraTraceConfigFileContent.Count | Should be 7
        }
        It "Testing ExtraTraceConfigFileContent type" {
            $ExtraTraceConfigFileContent[0].GetType().Name | Should Be "string"
        }
        It "Testing EnableEmailNotification not null" {
            $EnableEmailNotification | Should not be $null
        }
        It "Testing EnableEmailNotification type" {
            $EnableEmailNotification.GetType().Name | Should be "Boolean"
        }
        It "Testing EnableEmailNotification value" {
            $EnableEmailNotification | Should Be $false
        }
        It "Testing SMTPSender not null" {
            $SMTPSender | Should not be $null
        }
        It "Testing SMTPSender type" {
            $SMTPSender.GetType().Name | Should be "string"
        }
        It "Testing SMTPSender value" {
            $SMTPSender | Should be "david@adt.local"
        }
        It "Testing EventID not null" {
            $EventID | Should not be $null
        }
        It "Testing EventID type" {
            $EventID.GetType().Name | Should be "int32"
        }
        It "Testing EventID value" {
            $EventID | Should be 2024
        }
        It "Testing MDBFailureItemTags not null" {
            $MDBFailureItemTags | Should not be $null
        }
        It "Testing MDBFailureItemTags count" {
            $MDBFailureItemTags.count | Should be 2
        }
        It "Testing MDBFailureItemTags type" {
            $MDBFailureItemTags[0].GetType().Name | Should be "int32"
        }
    }
}