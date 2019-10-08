#Function Version 1.0
Function Write-HostWriter{
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($this.LoggerObject -eq $null)
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