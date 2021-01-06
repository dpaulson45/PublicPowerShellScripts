[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWMICmdlet', '', Justification = 'Testing')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Testing')]
#TODO: Need to finish
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

Function Get-WinHttpSettings {
    param(
        [Parameter(Mandatory = $true)][string]$RegistryLocation
    )
    $connections = Get-ItemProperty -Path $RegistryLocation
    $Proxy = [string]::Empty
    if (($null -ne $connections) -and
        ($Connections | Get-Member).Name -contains "WinHttpSettings") {
        foreach ($Byte in $Connections.WinHttpSettings) {
            if ($Byte -ge 48) {
                $Proxy += [CHAR]$Byte
            }
        }
    }
    return $(if ($Proxy -eq [string]::Empty) { "<None>" } else { $Proxy })
}

Function Get-PendingSCCMReboot {

    try {
        $sccmReboot = Invoke-CimMethod -Namespace 'Root\ccm\clientSDK' -ClassName 'CCM_ClientUtilities' -Name 'DetermineIfRebootPending' -ErrorAction Stop

        if ($sccmReboot) {
            if ($sccmReboot.RebootPending -or
                $sccmReboot.IsHardRebootPending) {
                return $true
            }
        }
        return $false
    } catch {
        throw
    }
}

$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain

Describe "Testing Invoke-ScriptBlockHandler" {

    Context "Good Local Test Results" {
        It "Processor Count" {
            $myValue = [System.Environment]::ProcessorCount
            $results = Invoke-ScriptBlockHandler -ComputerName $env:COMPUTERNAME -ScriptBlock { [System.Environment]::ProcessorCount } -ScriptBlockDescription "Getting Processor Count"
            $results | Should Be $myValue
        }
        It "Bad Server Name" {
            $results = Invoke-ScriptBlockHandler -ComputerName "Bad Computer Name" -ScriptBlock { [System.Environment]::ProcessorCount } -ScriptBlockDescription "Getting Processor Count"
            $results | Should Be $null
        }
        It "Passing Argument List" {
            $httpProxyPath32 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
            $testResults = Get-WinHttpSettings $httpProxyPath32
            $results = Invoke-ScriptBlockHandler -ComputerName $env:COMPUTERNAME -ScriptBlock ${Function:Get-WinHttpSettings} -ScriptBlockDescription "Getting Http Proxy Settings 32 bit" -ArgumentList $httpProxyPath32
        }
        It "Pending SCCM Reboot" {
            $results = Invoke-ScriptBlockHandler -ComputerName $env:COMPUTERNAME -ScriptBlock ${Function:Get-PendingSCCMReboot} -ScriptBlockDescription "Getting Pending SCCM Reboot Result"
            $results | Should Be $false
        }
    }
    Context "Remote Execution Test Results - Pester in Admin" {
        It "Processor Count" {
            $myValue = [System.Environment]::ProcessorCount
            $results = Invoke-ScriptBlockHandler -ComputerName $myFQDN -ScriptBlock { [System.Environment]::ProcessorCount } -ScriptBlockDescription "Getting Processor Count"
            $results | Should Be $myValue
        }
        It "Passing Argument List" {
            $httpProxyPath32 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
            $testResults = Get-WinHttpSettings $httpProxyPath32
            $results = Invoke-ScriptBlockHandler -ComputerName $myFQDN -ScriptBlock ${Function:Get-WinHttpSettings} -ScriptBlockDescription "Getting Http Proxy Settings 32 bit" -ArgumentList $httpProxyPath32
        }
    }
}