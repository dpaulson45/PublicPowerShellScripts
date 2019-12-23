# Get-ExchangeInstallDirectory
Function that is used to get the install directory for Exchange 2010 or newer from the local server.

# Parameters 

Parameter | Description 
----------|------------
InvokeCommandReturnWriteArray | When set to true, it enables the Write-*Writer functions and the Install Directory in a single object. 

# How To Use

Use the following sample code within your script: 

```
# Example 1: Without setting the InvokeCommandReturnWriteArray to true. 

$installDirectory = Get-ExchangeInstallDirectory 
```

```
# Example 2: With setting the InvokeCommandReturnWriteArray to true.

$Servers = @("ServerA","ServerB","ServerC")
$serversListInstall = @() 

foreach($server in $servers)
{
    $addObject = New-Object PSCustomObject 
    $addObject | Add-Member -MemberType NoteProperty -Name ServerName -Value $server 
    $addObject | Add-Member -MemberType NoteProperty -Name ArgumentList -Value $true 
    $serversListInstall += $addObject 
}

#create a string for the required functions of the Get-ExchangeInstallDirectory  SB to be able to execute it.
$addRequiredFunctions = "Function Write-InvokeCommandReturnVerboseWriter { " + (${Function:Write-InvokeCommandReturnVerboseWriter}).ToString() + " } `n `n Function Write-InvokeCommandReturnHostWriter { " + (${Function:Write-InvokeCommandReturnHostWriter}).ToString() + " } `n #" 

$scriptBlockString = (${Function:Get-ExchangeInstallDirectory }).ToString().Replace("#Function Version", $addRequiredFunctions)

$getExchangeInstallDirectoryScriptBlock = [scriptblock]::Create($scriptBlockString)

$serverToInstallDirectory = Start-JobManager -ServersWithArguments $serversListInstall -ScriptBlock $getExchangeInstallDirectoryScriptBlock `
    -NeedReturnData $true -DisplayReceiveJobInCorrectFunction $true -JobBatchName "Getting the Exchange Install Directory on the Servers" 

```