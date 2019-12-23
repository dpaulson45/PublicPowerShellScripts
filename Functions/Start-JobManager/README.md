# Start-JobManager
Function that is used to be able to pass of a script block with a list of servers to execute them with Invoke-Command as a job. This improves the time it takes to loop through some possible long running tasks on multiple servers at once vs one server at a time.

This is extremely useful for when you can't do all the servers at once with Invoke-Command normally if you are passing large objects. This way you can chuck up what you are sending and not run into a sizing issue. 

# Parameters

Parameter | Description
----------|------------
ServersWithArguments* | An array of objects that has two members. One is a ServerName that contains the ServerName that this script block should execute against. The second is an ArgumentList that is customized to your script block that you are passing. 
ScriptBlock | The script block that you wish to execute on the list of servers that you have provided with the possible option of ArgumentList
JobBatchName | Provides in debug information what job batch this is for. 
DisplayReceiveJob | Determines if we call Write-HostWriter for the received job information. 
DisplayReceiveJobInVerboseFunction | If data is returned, we will only display the information by calling Write-VerboseWriter 
DisplayReceiveJobInCorrectFunction** | If data is returned, we will determine what data type is returned and take action against it. This is used when you have a script block that you would also like to have verbose information or host information also to be displayed. This returns the data in a HashTable with the server name as the key and the value as the returned job information. 
NeedReturnData | If set to true, we will return the data from the job received. Can't be used with DisplayReceiveJobInCorrectFunction. This returns the data in a HashTable with the server name as the key and the value as the returned job information. 

***NOTE:** Here is how the object should look for ServersWithArguments array object.
<#
    [array]ServersWithArguments
        [string]ServerName
        [object]ArgumentList #customized for your scriptblock
#>


****NOTE:** This works only if the return type of the script block is an array with a hash table for the values. The acceptable Keys are "Verbose", "Host", and "ReturnObject". This allows for the local Write-VerboseWriter and Write-HostWriter functions to be called. 


# How To Use 

Use the following sample code within your script:

```
#Example 1: Using ScriptBlock New-Folder https://github.com/dpaulson45/PublicPowerShellScripts/tree/master/Functions/New-Folder

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