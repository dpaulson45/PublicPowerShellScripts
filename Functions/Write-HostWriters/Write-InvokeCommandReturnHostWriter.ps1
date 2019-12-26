#Function Version 1.0
Function Write-InvokeCommandReturnHostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString,
[int]$ScopeLevel = 1
)
    if($InvokeCommandReturnWriteArray)
    {
        $hashTable = @{"Host"=("[Remote Server: {0}] : {1}" -f $env:COMPUTERNAME, $WriteString)}
        Set-Variable stringArray -Value ($stringArray += $hashTable) -Scope $ScopeLevel 
    }
    else 
    {
        Write-HostWriter $WriteString
    }
}