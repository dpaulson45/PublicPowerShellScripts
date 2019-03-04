Function New-LoggerObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogDirectory = ".",
[Parameter(Mandatory=$false)][string]$LogName = "Script_Logging.txt",
[Parameter(Mandatory=$false)][bool]$OverWriteLog = $false,
[Parameter(Mandatory=$false)][bool]$EnableDateTime = $true, 
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.0
#[System.Collections.Generic.List[System.Object]]$list = New-Object -TypeName System.Collections.Generic.List[System.Object]

########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($this.VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        $this.VerboseFunctionCaller($WriteString)
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($this.HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        $this.HostFunctionCaller($WriteString)
    }
}

########################
#
# Template Functions
#
########################

Function Write-ToLog {
param(
[string]$WriteString,
[string]$LogLocation
)
    $WriteString | Out-File ($LogLocation) -Append
}

########################
#
# End Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($LogDirectory -eq ".")
{
    $LogDirectory = (Get-Location).Path
}
if([string]::IsNullOrWhiteSpace($LogName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogName" 
}
if(!(Test-Path $LogDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogDirectory" 
}

$fullLogPath = "{0}\{1}" -f $LogDirectory, $LogName

$loggerObject = New-Object pscustomobject 
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $LogDirectory
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $LogName
$loggerObject | Add-Member -MemberType NoteProperty -Name "FullPath" -Value $fullLogPath
$loggerObject | Add-Member -MemberType NoteProperty -Name "EnableDateTime" -Value $EnableDateTime
$loggerObject | Add-Member -MemberType ScriptMethod -Name "ToLog" -Value ${Function:Write-ToLog}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}

if($HostFunctionCaller -ne $null)
{
    $loggerObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $loggerObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteHost" -Value {
    param(
    [string]$LoggingString
    )
    if([string]::IsNullOrWhiteSpace($LoggingString))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LoggingString"
    }

    if($this.EnableDateTime)
    {
        $LoggingString = "[{0}] : {1}" -f [System.DateTime]::Now, $LoggingString
    }

    $this.WriteHostWriter($LoggingString)
    $this.ToLog($LoggingString, $this.FullPath)
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerbose" -Value {
    param(
    [string]$LoggingString
    )
    if([string]::IsNullOrWhiteSpace($LoggingString))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LoggingString"
    }

    if($this.EnableDateTime)
    {
        $LoggingString = "[{0}] : {1}" -f [System.DateTime]::Now, $LoggingString
    }
    $this.WriteVerboseWriter($LoggingString)
    $this.ToLog($LoggingString, $this.FullPath)

}

try 
{
    "[{0}] : Creating a new logger instance" -f [System.DAteTime]::Now | Out-File ($fullLogPath) -Append
}
catch 
{
    throw 
}

return $loggerObject
}