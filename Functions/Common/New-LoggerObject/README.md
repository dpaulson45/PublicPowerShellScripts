# New-LoggerObject
Function that is used to create an object for you to be able to write data within the script out to a log file if need be.

# Parameters 

Parameter | Description 
----------|------------
LogDirectory | Provide a valid directory where we are going to be writing out the log file. Default is current running path. 
LogName | Provide a custom name for the log file. Default "Script_Logging". 
EnableDateTime | Adds the current date and time to the line that you are writing out to the screen and log file. Default True.
IncludeDateTimeToFileName | Appends the date and time in the following format yyyyMMddHHmmss to the log file name. Default True.
MaxFileSizeInMB | The max size a file will get to before rolling over to the next log file. Default 10 MB. 
CheckSizeIntervalMinutes | The interval that we check the size of the log file. Default 10 Minutes. 
NumberOfLogsToKeep | The number of logs which we keep before removing the oldest to avoid the drive from filling up. Default 10 logs. 
VerboseEnabled | Used to enable verbose information to the screen. 
HostFunctionCaller | A script block that you can pass on object creation to allow a custom write host to be executed instead of the default that occurs. 
VerboseFunctionCaller | A script block that you can pass on object creation to allow a custom verbose write host information to be executed instead of the default that occurs. 

# Methods 

Method | Description
-------|------------
CheckFileSize() | Method used to check the current file size. 
CheckNumberOfFiles() | Method used to check the number of files with this instance's base name. 
LogUpKeep() | Runs the required Method to do proper up keep of the log(s). This is done automatically within each call to a Write method. 
ToLog(string WriteString, string LogLocation) | Writes out the data to the log file. This is done automatically within each call to a write method. 
UpdateFileLocation() | Updates the file location if a new file is needed to be created after the MaxFileSizeInMB is reached. 
WriteHost(string WriteString) | Used to call the WriteHostWriter() and ToLog() for what you wish to log. 
WriteVerbose(string WriteString) | used to call WriteVerboseWriter() and ToLog() for what you wish to log. Only information will be displayed if VerboseEnabled is set to true. 
WriteHostWriter(string WriteString) | Used to call Write-Host. 
WriteVerboseWriter(string WriteString) | Used to call Write-Host. Will only display information if VerboseEnabled is set to true.
DisableLogger() | Disable the logger from being able to do anything.
EnableLogger() | Enable the logger to work as normal.

# How To Use 

Use the following sample code within your script: 

```
if($PSBoundParameters["Verbose"])
{
    $Script:VerboseEnabled = $true 
}
else
{
    $Script:VerboseEnabled = $false
}
... 

$Script:Logger = New-LoggerObject -LogName "MyCustomLogger" -VerboseEnabled $Script:VerboseEnabled
#Some Code 
$Script:Logger.WriteVerbose("Made it into this function")

$Script:Logger.WriteHost("Hello World! - This is details that will always be displayed and logged") 
```