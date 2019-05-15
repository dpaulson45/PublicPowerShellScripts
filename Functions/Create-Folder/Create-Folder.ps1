Function Create-Folder {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$NewFolder,
[Parameter(Mandatory=$false)][array]$NewFolders,
[Parameter(Mandatory=$false)][bool]$IncludeDisplayCreate,
[Parameter(Mandatory=$false)][bool]$InvokeCommandReturnWriteArray,
[Parameter(Mandatory=$false,Position=1)][object]$PassedParametersObject,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)

#Function Version 1.3
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

Function New-Folder {
param(
[Parameter(Mandatory=$false)][string]$NewFolder
)
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
}
$passedVerboseFunctionCaller = $false
$passedHostFunctionCaller = $false
$passedPassedParametersObject = $false
$passedMultipleFolders = $false 
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
if($HostFunctionCaller -ne $null){$passedHostFunctionCaller = $true}
if($PassedParametersObject -ne $null){$passedPassedParametersObject = $true}
$stringArray = @() 
if($PassedParametersObject -ne $null)
{
    if($PassedParametersObject.NewFolder -ne $null)
    {
        $NewFolder = $PassedParametersObject.NewFolder 
    }
    if($PassedParametersObject.NewFolders -ne $null)
    {
        $NewFolders = $PassedParametersObject.NewFolders
    }
    $InvokeCommandReturnWriteArray = $true 
}
if($NewFolders -ne $null){$passedMultipleFolders = $true}
Write-VerboseWriter("Calling: Create-Folder")
Write-VerboseWriter("Passed: [string]NewFolder: {0} | [bool]IncludeDisplayCreate: {1} | [bool]InvokeCommandReturnWriteArray: {2} | [bool]PassedMultipleFolders: {3} | [object]PassedParametersObject: {4} | [scriptblock]VerboseFunctionCaller: {5} | [scriptblock]HostFunctionCaller: {6}" -f $NewFolder,
$IncludeDisplayCreate,
$InvokeCommandReturnWriteArray,
$passedMultipleFolders,
$passedPassedParametersObject,
$passedVerboseFunctionCaller,
$passedHostFunctionCaller)

if($NewFolder -ne $null -and $NewFolders -eq $null)
{
    Write-VerboseWriter("Creating a single folder")
    New-Folder -NewFolder $NewFolder 
}
elseif($NewFolders -ne $null)
{
    Write-VerboseWriter("Creating multiple folders")
    foreach($newFolder in $NewFolders)
    {
        New-Folder -NewFolder $newFolder 
    }
}
else 
{
    Write-HostWriter("Failed to provide valid options to create a folder.")
}

if($InvokeCommandReturnWriteArray)
{
    return $stringArray
}
}