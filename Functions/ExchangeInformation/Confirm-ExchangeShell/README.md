# Confirm-ExchangeShell
Function that is used to check to see if your PowerShell session has Exchange Management Shell is loaded. It returns a custom object back providing different pieces of information. 

# Parameters 

Parameter | Description
----------|------------
LoadExchangeShell | It will attempt to load the Exchange Management Shell if it isn't detected to be loaded via Get-ExchangeServer. Default: $true
CatchActionFunction | It will perform a script block action if passed in a Catch section of the function.

# Properties 

Property | Description
---------|------------
ShellLoaded | Determines if Exchange Management Shell is loaded or not.
Major | Provides the Major build of the load computer from the registry
Minor | Provides the Minor build of the load computer from the registry
Build | Provides the Build build of the load computer from the registry
Revision | Provides the Revision build of the load computer from the registry
ToolsOnly | Determines if this is a tools only computer or not
RemoteShell | Determines if that we are connect to Exchange Management Shell through a remote shell connection.

# How To Use

Use the following sample code within your script: 

```

$exchangeShell = Confirm-ExchangeShell

if(!($exchangeShell.ShellLoaded))
{
    Write-Host("Failed to load the Exchange Management Shell, failing out the script.")
    exit
}

if ($exchangeShell.ToolsOnly -or $exchangeShell.RemoteShell)
{
    Write-Host("Using Exchange Management Shell from a non Exchange Server.")
}

```