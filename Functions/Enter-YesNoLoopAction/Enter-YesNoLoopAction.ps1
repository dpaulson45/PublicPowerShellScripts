Function Enter-YesNoLoopAction {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Question,
[Parameter(Mandatory=$true)][scriptblock]$YesAction,
[Parameter(Mandatory=$true)][scriptblock]$NoAction,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.1
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
    
$passedVerboseFunctionCaller = $false
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
Write-VerboseWriter("Calling: Enter-YesNoLoopAction")
Write-VerboseWriter("Passed: [string]Question: {0} | [bool]VerboseFunctionCaller: {1}" -f $Question, 
$passedVerboseFunctionCaller)

do{
    $answer = Read-Host ("{0} ('y' or 'n')" -f $Question)
    Write-VerboseWriter("Read-Host answer: {0}" -f $answer)
}while($answer -ne 'n' -and $answer -ne 'y')

if($answer -eq 'y')
{
    &$YesAction
}
else 
{
    &$NoAction
}
}