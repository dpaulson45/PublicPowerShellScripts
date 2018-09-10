[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][bool]$InvokeCommandReturnWriteArray,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)

#Function Version 1.0
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
$stringArray = @()
Write-VerboseWriter("Calling: Get-ExchangeInstallDirectory")
Write-VerboseWriter("Passed: [bool]InvokeCommandReturnWriteArray: {0} | [scriptblock]VerboseFunctionCaller: {1} | [scriptblock]HostFunctionCaller: {2}" -f $InvokeCommandReturnWriteArray, 
$passedVerboseFunctionCaller, 
$passedHostFunctionCaller)

$installDirectory = [string]::Empty
if(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup')
{
    Write-VerboseWriter("Detected v14")
    $installDirectory = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup).MsiInstallPath 
}
elseif(Test-Path 'HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup')
{
    Write-VerboseWriter("Detected v15")
    $installDirectory = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup).MsiInstallPath	
}
else 
{
    Write-HostWriter -WriteString ("Something went wrong trying to find Exchange Install path on this server: {0}" -f $env:COMPUTERNAME)  
}
Write-VerboseWriter("Returning: {0}" -f $installDirectory)
if($InvokeCommandReturnWriteArray)
{
    $hashTable = @{"ReturnObject"=$installDirectory}
    $stringArray += $hashTable
    return $stringArray
}
return $installDirectory