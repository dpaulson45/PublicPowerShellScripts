[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$NewFolder,
[Parameter(Mandatory=$false)][bool]$IncludeDisplayCreate,
[Parameter(Mandatory=$false)][bool]$InvokeCommandReturnWriteArray,
[Parameter(Mandatory=$false,Position=1)][object]$PassedParametersObject,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)

#Function Version 1.1
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
$passedPassedParametersObject = $false
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
if($HostFunctionCaller -ne $null){$passedHostFunctionCaller = $true}
if($passedPassedParametersObject -ne $null){$passedPassedParametersObject = $true}
$stringArray = @() 
if($PassedParametersObject -ne $null)
{
    $NewFolder = $PassedParametersObject.NewFolder 
    $InvokeCommandReturnWriteArray = $true 
}
Write-VerboseWriter("Calling: Create-Folder")
Write-VerboseWriter("Passed: [string]NewFolder: {0} | [bool]IncludeDisplayCreate: {1} | [bool]InvokeCommandReturnWriteArray: {2} | [object]PassedParametersObject: {3} | [scriptblock]VerboseFunctionCaller: {4} | [scriptblock]HostFunctionCaller: {5}" -f $NewFolder,
$IncludeDisplayCreate,
$InvokeCommandReturnWriteArray,
$passedPassedParametersObject,
$passedVerboseFunctionCaller,
$passedHostFunctionCaller)

if(-not (Test-Path -Path $NewFolder))
{
    if($IncludeDisplayCreate -or $InvokeCommandReturnWriteArray)
    {
        Write-HostWriter("Creating Directory: {0}" -f $NewFolder)
    }
    [System.IO.Directory]::CreateDirectory($NewFolder) | Out-Null
}
else 
{
    if($IncludeDisplayCreate -or $InvokeCommandReturnWriteArray)
    {
        Write-HostWriter("Directory {0} is already created!" -f $NewFolder)
    }
}
if($InvokeCommandReturnWriteArray)
{
    return $stringArray
}