[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$NewFolder,
[Parameter(Mandatory=$false)][bool]$IncludeDisplayCreate,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)

#Function Version 1.0
Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($VerboseFunctionCaller -eq $null)
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
        if($HostFunctionCaller -eq $null)
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
Write-VerboseWriter("Calling: Create-Folder")
Write-VerboseWriter("Passed: [string]NewFolder: {0} | [bool]IncludeDisplayCreate: {1} | [scriptblock]VerboseFunctionCaller: {2} | [scriptblock]HostFunctionCaller: {3}" -f $NewFolder,
$IncludeDisplayCreate,
$passedVerboseFunctionCaller,
$passedHostFunctionCaller)

if(-not (Test-Path -Path $NewFolder))
{
    if($IncludeDisplayCreate)
    {
        Write-HostWriter("Creating Directory: {0}" -f $NewFolder)
    }
    [System.IO.Directory]::CreateDirectory($NewFolder) | Out-Null
}
else 
{
    if($IncludeDisplayCreate)
    {
        Write-HostWriter("Directory {1} is already created!" -f $NewFolder)
    }
}