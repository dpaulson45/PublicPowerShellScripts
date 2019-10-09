#Function Version 1.0
Function Write-ScriptMethodHostWriter{
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($this.LoggerObject -ne $null)
    {
        $this.LoggerObject.WriteHost($WriteString) 
    }
    elseif($this.HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else 
    {
        $this.HostFunctionCaller($WriteString)
    }
}