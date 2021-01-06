# Confirm-Administrator
Function that is used to check to see if your PowerShell script is running as an Admin or not. 

# How To Use

Use the following sample code within your script: 

```
if(!Confirm-Administrator)
{
    Write-Host("Not running as an Administrator. Please close the PowerShell window and open it as an Administrator.")
    exit 
}

```