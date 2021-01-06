# Confirm-ExchangeShell
Function that is used to check to see if your PowerShell session has Exchange Management Shell is loaded. It returns a boolean if we have Exchange Shell Loaded or were able to load it.

# Parameters 

Parameter | Description
----------|------------
LoadExchangeShell | It will attempt to load the Exchange Management Shell if it isn't detected to be loaded via Get-ExchangeServer. Default: $true
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