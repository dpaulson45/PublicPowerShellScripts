Function Confirm-ExchangeShell {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][bool]$LoadExchangeShell = $true,
[Parameter(Mandatory=$false)][bool]$LoadExchangeVariables = $true,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)
#Function Version 1.2
Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($InvokeCommandReturnWriteArray)
    {
    $hashTable = @{"Verbose"=("[Remote Server: {0}] : {1}" -f $env:COMPUTERNAME, $WriteString)}
    Set-Variable stringArray -Value ($stringArray += $hashTable) -Scope 1 
    }
    elseif($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
        
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($InvokeCommandReturnWriteArray)
    {
        $hashTable = @{"Host"=("[Remote Server: {0}] : {1}" -f $env:COMPUTERNAME, $WriteString)}
        Set-Variable stringArray -Value ($stringArray += $hashTable) -Scope 1 
    }
    elseif($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}
        
$passedVerboseFunctionCaller = $false
$passedHostFunctionCaller = $false
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
if($HostFunctionCaller -ne $null){$passedHostFunctionCaller = $true}

$passed = $false 
Write-VerboseWriter("Calling: Confirm-ExchangeShell")
Write-VerboseWriter("Passed: [bool]LoadExchangeShell: {0} | [bool]LoadExchangeVariables: {1} | [scriptblock]VerboseFunctionCaller: {2} | [scriptblock]HostFunctionCaller: {3}" -f $LoadExchangeShell,
$LoadExchangeVariables,
$passedVerboseFunctionCaller,
$passedHostFunctionCaller)
#Test that we are on Exchange 2010 or newer
if((Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup') -or 
(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup'))
{
    Write-VerboseWriter("We are on Exchange 2010 or newer")
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "stop"
    try 
    {
        Get-ExchangeServer | Out-Null
        $passed = $true 
    }
    catch 
    {
        Write-VerboseWriter("Failed to run Get-ExchangeServer")
        if($LoadExchangeShell)
        {
            Write-HostWriter "Loading Exchange PowerShell Module..."
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