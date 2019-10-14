param(
[string]$Server
)

if([string]::IsNullOrEmpty($Server))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid server" 
}

try 
{
    Invoke-Command -ComputerName $Server -ScriptBlock {Restart-Service MSExchangeTransport -Force} -ErrorAction Stop 
}
catch 
{
    throw "Failed to run Invoke-Command"
}