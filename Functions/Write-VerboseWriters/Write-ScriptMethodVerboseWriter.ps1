#Function Version 1.0
Function Write-ScriptMethodVerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($this.LoggerObject -ne $null)
    {
        $this.LoggerObject.WriteVerbose($WriteString)
    }
    elseif($this.VerboseFunctionCaller -eq $null -and 
        $this.WriteVerboseData)
    {
        Write-Host $WriteString -ForegroundColor Cyan 
    }
    elseif($this.WriteVerboseData)
    {
        $this.VerboseFunctionCaller($WriteString)
    }
}