# Confirm-ExchangeShell
Function that is used to check to see if your PowerShell session has Exchange Management Shell is loaded. If it isn't it can load it for you and set the $Global:ExInstall and $Global:ExBin variables for you. 

# Parameters 

Parameter | Description
----------|------------
LoadExchangeShell | It will attempt to load the Exchange Management Shell if it isn't detected to be loaded via Get-ExchangeServer. Default: $true
LoadExchangeVariables | It will set the $Global:ExInstall and $Global:ExBin location if it is detected they aren't set. Default: $true
ByPassLocalExchangeServerTest | Allows the ability to use this function in a script that can be used on a remote computer that doesn't have Exchange Management installed on it. Default: $false
CatchActionFunction | It will perform a script block action if passed in a Catch section of the function. 

# How To Use

Use the following sample code within your script: 

```
if(!(Confirm-ExchangeShell))
{
    Write-Host("Failed to load the Exchange Management Shell, failing out the script.")
    exit
}
```