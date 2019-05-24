Function Invoke-ScriptBlockHandler {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ComputerName,
[Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
[Parameter(Mandatory=$false)][string]$ScriptBlockDescription,
[Parameter(Mandatory=$false)][object]$ArgumentList,
[Parameter(Mandatory=$false)][scriptblock]$CatchActionFunction
)
#Function Version 1.0
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>
Write-VerboseWriter("Calling: Invoke-ScriptBlockHandler")
if(![string]::IsNullOrEmpty($ScriptBlockDescription))
{
    Write-VerboseWriter($ScriptBlockDescription)
}
try 
{
    if($ComputerName -ne $env:COMPUTERNAME)
    {
        if($ArgumentList -ne $null) 
        {
            Write-VerboseWriter("Running Invoke-Command with argument list.")
            $invokeReturn = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ErrorAction Stop 
        }
        else 
        {
            Write-VerboseWriter("Running Invoke-Command without argument list.")
            $invokeReturn = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ErrorAction Stop 
        }
        return $invokeReturn 
    }
    else 
    {
        if($ArgumentList -ne $null)
        {
            Write-VerboseWriter("Running Script Block locally with argument list.")
            $localReturn = & $ScriptBlock $ArgumentList 
        }
        else 
        {
            Write-VerboseWriter("Running Script Block locally without argument list.")
            $localReturn = & $ScriptBlock      
        }
        return $localReturn 
    }
}
catch 
{
    Write-VerboseWriter("Failed to Invoke-ScriptBlockHandler")
    if($CatchActionFunction -ne $null)
    {
        & $CatchActionFunction 
    }
}
}