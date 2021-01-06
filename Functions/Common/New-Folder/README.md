# New-Folder
Function that is used to be able to create a folder on a system. 

# Parameters 

Parameter | Description 
----------|------------
NewFolders | An array of full folder paths that you wish to create. An alias of this parameter is NewFolder.
IncludeDisplayCreate | Determines if you display if the folder is created or not to the Write-InvokeCommandReturnHostWriter. 
PassedParametersObject | Position = 1. This is used to pass an object from an argument list from Invoke-Command. This sets the InvokeCommandReturnWriteArray to true and will return an array of a hashtable of the verbose and host information that was run against the script. 

# How To Use

Use the following sample code within your script: 

```
#Example 1: Typical Use

$myFolders = @("C:\Users\Admin\Desktop\Testing\SubFolder1", "C:\Users\Admin\Desktop\Testing\SubFolder1")

New-Folder -NewFolders $myFolders -IncludeDisplayCreate $true 

```

```
#Example 2: Advanced Use within Start-JobManager https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/Start-JobManager

#Ready the ServersWithArguments object for Start-JobManager
$myFolders = @("C:\Users\Admin\Desktop\Testing\SubFolder1", "C:\Users\Admin\Desktop\Testing\SubFolder1")
$servers = @("ServerA","ServerB","ServerC")
$serversDirectories = @() 

foreach($server in $servers)
{
    $addObject = New-Object PSCustomObject 
    $addObject | Add-Member -MemberType NoteProperty -Name ServerName -Value $server
    $addObject | Add-Member -MemberType NoteProperty -Name ArgumentList -Value $myFolders 
    $serversDirectories += $addObject
}

#create a string for the required functions of the New-Folder SB to be able to execute it.
$addRequiredFunctions = "Function Write-InvokeCommandReturnVerboseWriter { " + (${Function:Write-InvokeCommandReturnVerboseWriter}).ToString() + " } `n `n Function Write-InvokeCommandReturnHostWriter { " + (${Function:Write-InvokeCommandReturnHostWriter}).ToString() + " } `n #" 

$scriptBlockString = (${Function:New-Folder}).ToString().Replace("#Function Version", $addRequiredFunctions)

$newFolderScriptBlock = [scriptblock]::Create($scriptBlockString)

Start-JobManager -ServersWithArguments $serversDirectories -ScriptBlock $newFolderScriptBlock -DisplayReceiveJobInCorrectFunction $true -JobBatchName "Creating folders on the servers" 


```