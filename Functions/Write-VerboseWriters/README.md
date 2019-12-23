# Write-VerboseWriter

Function that commonly used throughout all my other functions to provide additional information that could be extremely useful to debug a function or understand why something is occurruing. 

# Write-ScriptMethodVerboseWriter

Function that is commonly used when using a script method within an object that you are returning. 

# Write-InvokeCommandReturnVerboseWriter

Function that is used to be able to return an array with a hashtable of information that you are requesting to normally have been displayed in Write-VerboseWriter. This is only done if the variable InvokeCommandReturnWriteArray is set to true. Otherwise, normal flow will be executed with Write-VerboseWriter. 

If InvokeCommandReturnWriteArray is set to true, the function will set a variable named stringArray with the default scope value of 1. An increased number is only needed when we need to access the variable from a lower caller in the stack. 