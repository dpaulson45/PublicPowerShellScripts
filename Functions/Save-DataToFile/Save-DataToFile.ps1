[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$DataIn,
[Parameter(Mandatory=$true)][string]$SaveToLocation,
[Parameter(Mandatory=$false)][bool]$FormatList = $true,
[Parameter(Mandatory=$false)][bool]$SaveTextFile = $true,
[Parameter(Mandatory=$false)][bool]$SaveXMLFile = $true,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
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

$passedVerboseFunctionCaller = $false
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
Write-VerboseWriter("Calling: Save-DataToFile")
Write-VerboseWriter("Passed: [string]SaveToLocation: {0} | [bool]FormatList: {1} | [bool]SaveTextFile: {2} | [bool]SaveXMLFile: {3} | [scriptblock]VerboseFunctionCaller: {4}" -f $SaveToLocation,
$FormatList,
$SaveTextFile,
$SaveXMLFile,
$passedVerboseFunctionCaller)

$xmlSaveLocation = "{0}.xml" -f $SaveToLocation
$txtSaveLocation = "{0}.txt" -f $SaveToLocation

if($DataIn -ne [string]::Empty)
{
    if($SaveXMLFile)
    {
        $DataIn | Export-Clixml $xmlSaveLocation -Encoding UTF8
    }
    if($SaveTextFile)
    {
        if($FormatList)
        {
            $DataIn | Format-List * | Out-File $txtSaveLocation
        }
        else 
        {
            $DataIn | Format-Table -AutoSize | Out-File $txtSaveLocation    
        }
    }
    
}
else
{
    Write-VerboseWriter("DataIn was an empty string. No going to save anything.")
}