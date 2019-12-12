Function Confirm-ExchangeShell {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][bool]$LoadExchangeShell = $true,
[Parameter(Mandatory=$false)][bool]$LoadExchangeVariables = $true
)
#Function Version 1.3
<#
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-HostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>

$passed = $false 
Write-VerboseWriter("Calling: Confirm-ExchangeShell")
Write-VerboseWriter("Passed: [bool]LoadExchangeShell: {0} | [bool]LoadExchangeVariables: {1}" -f $LoadExchangeShell,
$LoadExchangeVariables)
#Test that we are on Exchange 2010 or newer
if((Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup') -or 
(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup'))
{
    Write-VerboseWriter("We are on Exchange 2010 or newer")
    try 
    {
        Get-ExchangeServer -ErrorAction Stop | Out-Null
        Write-VerboseWriter("Exchange PowerShell Module already loaded.")
        $passed = $true 
    }
    catch 
    {
        Write-VerboseWriter("Failed to run Get-ExchangeServer")
        if($LoadExchangeShell)
        {
            Write-HostWriter "Loading Exchange PowerShell Module..."
            try
            {
                Import-Module $env:ExchangeInstallPath\bin\RemoteExchange.ps1 -ErrorAction Stop
                Connect-ExchangeServer -Auto -ClientApplication:ManagementShell 
                $passed = $true 
                #We are just going to assume this passed. 
            }
            catch 
            {
                Write-HostWriter("Failed to Load Exchange PowerShell Module...")
            }
        }
    }
    finally 
    {
        if($LoadExchangeVariables -and 
            $passed)
        {
            if($exinstall -eq $null -or $exbin -eq $null)
            {
                if(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup')
                {
                    $Global:exinstall = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup).MsiInstallPath	
                }
                else
                {
                    $Global:exinstall = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup).MsiInstallPath	
                }

                $Global:exbin = $Global:exinstall + "\Bin"

                Write-VerboseWriter("Set exinstall: {0}" -f $Global:exinstall)
                Write-VerboseWriter("Set exbin: {0}" -f $Global:exbin)
            }
        }
    }
}
else 
{
    Write-VerboseWriter("Does not appear to be an Exchange 2010 or newer server.")
}
Write-VerboseWriter("Returned: {0}" -f $passed)
return $passed
}