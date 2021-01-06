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

Function Get-SCCMRebootObject {
    $t = New-Object PSCustomObject
    $t | Add-Member -MemberType NoteProperty -Name "RebootPending" -Value $false
    $t | Add-Member -MemberType NoteProperty -Name "IsHardRebootPending" -Value $false
    return $t
}

Describe "Testing Get-ServerRebootPending" {
    Context "Good Test with throws" {
        Mock Get-ItemProperty { throw }
        Mock Invoke-CimMethod { throw }
        Mock Test-Path { return $false }
        It "Get-ServerRebootPending reboot not pending" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $false
        }
        Mock Test-Path { return $true }
        It "Get-ServerRebootPending reboot is pending" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $true
        }
    }
    Context "Good Test with throws - no mock on Test-Path" {
        Mock Get-ItemProperty { throw }
        Mock Invoke-CimMethod { throw }
        It "Get-ServerRebootPending reboot not pending" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $false
        }
    }

    Context "Full Test on Get-PendingSCCMReboot" {
        Mock Get-ItemProperty { throw }
        Mock Test-Path { return $false }
        Mock Invoke-CimMethod { return $null }
        It "Get-ServerRebootPending reboot not pending - CimMethod null" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $false
        }
        Mock Invoke-CimMethod { return Get-SCCMRebootObject }
        It "Get-ServerRebootPending reboot not pending - CimMethod both values set to false" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $false
        }
        Mock Invoke-CimMethod { $r = Get-SCCMRebootObject; $r.RebootPending = $true; return $r }
        It "Get-ServerRebootPending reboot pending - CimMethod RebootPending set to true" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $true
        }
        Mock Invoke-CimMethod { $r = Get-SCCMRebootObject; $r.IsHardRebootPending = $true; return $r }
        It "Get-ServerRebootPending reboot pending - CimMethod IsHardRebootPending set to true" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $true
        }
    }

    Context "Test out Get-PendingFileReboot" {
        Mock Test-Path { return $false }
        Mock Invoke-CimMethod { return $null }
        Mock Get-ItemProperty { return $false }
        It "Get-ServerRebootPending reboot not pending" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $false
        }
        Mock Get-ItemProperty { return $true }
        It "Get-ServerRebootPending reboot pending" {
            $results = Get-ServerRebootPending -ServerName $env:COMPUTERNAME
            $results.PendingReboot | Should Be $true
        }
    }
}