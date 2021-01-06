[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '', Justification = 'Testing reasons')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This is what i want to use')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWMICmdlet', '', Justification = 'This is what i want to use')]
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
        $webRequest = Invoke-WebRequest $line.Trim() -UseBasicParsing
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

$cimSession = New-CimSession -ComputerName $env:COMPUTERNAME -ErrorAction Stop
$networkCards = Get-NetAdapter -CimSession $cimSession | Where-Object { $_.MediaConnectionState -eq "Connected" } -ErrorAction Stop
$wmiNetworkCards = Get-WmiObject -ComputerName $env:COMPUTERNAME -Class "Win32_NetworkAdapter" -Filter "NetConnectionStatus ='2'"
#$fqdn = "{0}.{1}" -f $env:COMPUTERNAME, $env:USERDNSDOMAIN

Function Invoke-TestCatchAction {
    $Script:ErrorCount++
    Write-Host("Caught Error in Test Catch Action") -ForegroundColor "Yellow"
}

Function Test-BasicsResults ([object]$TestingResults, [object]$BaseCompareResults) {
    It "Testing Name" {
        $TestingResults.Name | Should Be $BaseCompareResults.Name
    }
    It "Testing LinkSpeed" {
        $TestingResults.LinkSpeed | Should Be ((($BaseCompareResults.Speed) / 1000000).ToString() + " Mbps")
    }
}

Function Test-Windows2012R2AndAbove ([object]$TestingResults, [object]$BaseCompareResults) {
    It "Testing Driver Date" {
        $TestingResults.DriverDate | Should Be $BaseCompareResults.DriverDate
    }
    It "Testing Description" {
        $TestingResults.Description | Should Be $BaseCompareResults.InterfaceDescription
    }
    It "Testing MtuSize" {
        $TestingResults.MtuSize | Should Be $BaseCompareResults.MtuSize
    }
    It "Testing Driver Version" {
        $TestingResults.DriverVersion | Should Be $BaseCompareResults.DriverVersionString
    }
    Test-BasicsResults -TestingResults $TestingResults -BaseCompareResults $BaseCompareResults
}

Function Test-Windows2012AndBelow ([object]$TestingResults, [object]$BaseCompareResults) {
    It "Testing Driver Date" {
        $TestingResults.DriverDate | Should Be ([DateTime]::MaxValue)
    }
    It "Testing Description" {
        $TestingResults.Description | Should Be $BaseCompareResults.Description
    }
    Test-BasicsResults -TestingResults $TestingResults -BaseCompareResults $BaseCompareResults
}
Describe "Testing Get-AllNicInformation" {
    Context "Windows 2012 R2 and newer - good local results" {
        $results = Get-AllNicInformation -ComputerName $env:COMPUTERNAME
        Test-Windows2012R2AndAbove -TestingResults $results -BaseCompareResults $networkCards
    }
    Context "Windows 2012 R2 failure to FQDN - but just use normal computer name as FQDN needs elevated rights" {
        $currentErrorCount = $Error.Count
        $results = Get-AllNicInformation -ComputerName  "VeryBadName" -ComputerFQDN $env:COMPUTERNAME -Verbose -CatchActionFunction ${Function:Invoke-TestCatchAction}
        Test-Windows2012R2AndAbove -TestingResults $results -BaseCompareResults $networkCards
        It "Testing Error catch" {
            $Error.Count - $Script:ErrorCount | Should Be $currentErrorCount
        }
    }
    Context "Windows 2012 R2 full failure on newest information" {
        $currentErrorCount = $Error.Count
        $Script:ErrorCount = 0
        Mock Get-NetAdapter { throw }
        $results = Get-AllNicInformation -ComputerName $env:COMPUTERNAME -Verbose -CatchActionFunction ${Function:Invoke-TestCatchAction}
        Test-Windows2012AndBelow -TestingResults $results -BaseCompareResults $wmiNetworkCards
        It "Testing Error catch" {
            $Error.Count - $Script:ErrorCount | Should Be $currentErrorCount
        }
    }
    Context "Windows 2012 R2 full failure on newest information with FQDN" {
        $currentErrorCount = $Error.Count
        $Script:ErrorCount = 0
        $Script:SecondAttempt = $false
        Mock Get-NetAdapter { throw }
        $results = Get-AllNicInformation -ComputerName $env:COMPUTERNAME -Verbose -CatchActionFunction ${Function:Invoke-TestCatchAction} -ComputerFQDN $env:COMPUTERNAME
        Test-Windows2012AndBelow -TestingResults $results -BaseCompareResults $wmiNetworkCards
        It "Testing Error catch" {
            $Error.Count - $Script:ErrorCount | Should Be $currentErrorCount
        }
    }
    Context "Windows 2012 and below good tests" {
        $results = Get-AllNicInformation -ComputerName $env:COMPUTERNAME -Verbose -CatchActionFunction ${Function:Invoke-TestCatchAction} -Windows2012R2AndAbove $false
        Test-Windows2012AndBelow -TestingResults $results -BaseCompareResults $wmiNetworkCards
    }

    Context "Windows 2012 and below failure" {
        Mock Get-WmiObject { throw }
        $results = Get-AllNicInformation -ComputerName $env:COMPUTERNAME -Verbose -CatchActionFunction ${Function:Invoke-TestCatchAction} -Windows2012R2AndAbove $false
        $results | Should Be $null
    }
}