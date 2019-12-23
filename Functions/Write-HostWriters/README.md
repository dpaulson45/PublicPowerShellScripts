# Write-HostWriter

Function that commonly used throughout all my other functions to provide a consistent Write-Host option.

# Write-ScriptMethodHostWriter

Function that is commonly used when using a script method within an object that you are returning. 

# Write-InvokeCommandReturnHostWriter

Function that is used to be able to return an array with a hashtable of information that you are requesting to normally have been displayed in Write-HostWriter. This is only done if the variable InvokeCommandReturnWriteArray is set to true. Otherwise, normal flow will be executed with Write-HostWriter. 

If InvokeCommandReturnWriteArray is set to true, the function will set a variable named stringArray with the default scope value of 1. An increased number is only needed when we need to access the variable from a lower caller in the stack. 