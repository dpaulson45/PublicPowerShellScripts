[CmdletBinding()]
param(
[bool]$LoadExchangeShell = $true,
[bool]$LoadExchangeVariables = $true  
)

$passed = $false 
#Test that we are on Exchange 2010 or newer
if((Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup') -or 
(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup'))
{
    Write-Verbose("We are on Exchange 2010 or newer")
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "stop"
    try 
    {
        Get-ExchangeServer | Out-Null
        $passed = $true 
    }
    catch 
    {
        Write-Verbose("Failed to run Get-ExchangeServer")
        if($LoadExchangeShell)
        {
            Write-Host "Loading Exchange PowerShell Module..."
            Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
            $passed = $true 
        }
    }
    finally 
    {
        $ErrorActionPreference = $oldErrorActionPreference
        if($LoadExchangeVariables)
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

                Write-Verbose("Set exinstall: {0}" -f $Global:exinstall)
                Write-Verbose("Set exbin: {0}" -f $Global:exbin)
            }
        }
    }
}
else 
{
    Write-Verbose("Does appear to be an Exchange 2010 or newer server.")
}

return $passed