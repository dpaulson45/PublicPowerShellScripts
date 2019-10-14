<#
Name: Start-ActiveDirectoryAndClientTracing.ps1
Author: David Paulson

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#>
[CmdletBinding()]
param(
[bool]$ClientProcdumpCollectionEnabled,
[string]$ClientProcdumpBinaryLocation,
[string]$ClientProcdumpProcessName,
[bool]$ClientPerformanceDataCollectionSetEnabled,
[string]$ClientPerformanceDataCollectionSetLogmanName,
[array]$ClientPerformanceDataCollectionSetCounters,
[int]$ClientPerformanceDataCollectionSetInterval,
[int]$ClientPerformanceDataCollectionSetMaxSize,
[bool]$ClientLDAPTracingEnabled,
[string]$ClientLDAPTracingLogmanName,
[string]$ClientLDAPTracingProvider,
[int]$ClientLDAPTracingMaxSizeMB,
[bool]$ClientLDAPTracingStopAfterIssueDetected,
[bool]$ActiveDirectoryPerformanceDataCollectorSetEnabled,
[array]$ActiveDirectoryPerformanceDataCollectorSetCounters,
[int]$ActiveDirectoryPerformanceDataCollectorSetInterval,
[int]$ActiveDirectoryPerformanceDataCollectorSetMaxSize,
[string]$ActiveDirectoryPerformanceDataCollectorSetLogmanName,
[bool]$ActiveDirectoryDiagnosticsEnabled,
[bool]$ActiveDirectoryDiagnosticsAfterIssueOccursOnly,
[bool]$ActiveDirectoryPerformanceDataCollectorSetStopAfterDiagnosticsStarted,
[bool]$ActiveDirectoryRemoteCredentialNotNeeded,
[PSCredential]$ActiveDirectoryRemoteCredentials,
[bool]$MonitorCounterTypeEnabled,
[string]$MonitorCounterTypeCounterName,
[array]$MonitorCounterTypeMultipleCounterNames, #TODO, currently not in use. 
[double]$MonitorCounterTypeAverageThreshold,
[double]$MonitorCounterTypeMaxThreshold,
[string]$MonitorCounterTypeThresholdType,
[int]$MonitorCounterTypeMaxSamples,
[int]$MonitorCounterTypeSleepInSeconds,
[bool]$MailNotificationEnabled,
[string]$MailNotificationSender,
[array]$MailNotificationRecipients,
[array]$MailNotificationSmtpServers,
[bool]$MailNotificationRequireCredentials,
[string]$MailNotificationMessageSubject,
[array]$ActiveDirectoryServers,
[string]$ActiveDirectorySavePath,
[array]$ClientServers,
[string]$ClientSaveAllDataPath,
[int]$MinutesToContinueDataCollectionAfterIssueDetected,
[bool]$MinimizeIssueScriptEnabled,
[string]$MinimizeIssueScriptPath,
[int]$MinutesWaitDurationBetweenIssues,
[int]$IssueCount = 3,
[switch]$StopDataCollectors
)

$scriptVersion = 0.1

$display = @"

    Enable Active Directory and Client Tracing Monitoring Script v{0}

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"@ -f $scriptVersion

$scriptName = "ActiveDirectoryAndClientTracing"
$scriptConfig = "{0}\{1}.config" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), (Split-Path -Leaf $MyInvocation.MyCommand.Path)

if($PSBoundParameters["Verbose"])
{
    $Script:VerboseEnabled = $true
}
else 
{
    $Script:VerboseEnabled = $false 
}

#Function Version 1.0
#[System.Collections.Generic.List[System.Object]]$list = New-Object -TypeName System.Collections.Generic.List[System.Object]

########################
#
# Write Functions 
#
########################

#Master Template: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#Function Version 1.0
Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteVerbose($WriteString)
    }
    elseif($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}

#Master Template: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#Function Version 1.0
Function Write-ScriptMethodVerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($this.LoggerObject -ne $null)
    {
        $this.LoggerObject.WriteVerbose($WriteString)
    }
    elseif($this.VerboseFunctionCaller -eq $null -and 
        $this.WriteVerboseData)
    {
        Write-Host $WriteString -ForegroundColor Cyan 
    }
    elseif($this.WriteVerboseData)
    {
        $this.VerboseFunctionCaller($WriteString)
    }
}

#Master Template: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-HostWriter.ps1
#Function Version 1.0
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteHost($WriteString) 
    }
    elseif($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}

#Master Template: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
#Function Version 1.0
Function Write-ScriptMethodHostWriter{
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($this.LoggerObject -ne $null)
    {
        $this.LoggerObject.WriteHost($WriteString) 
    }
    elseif($this.HostFunctionCaller -eq $null)
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

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-MailMessageObject/New-MailMessageObject.ps1
Function New-MailMessageObject {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)][string]$SMTPSender,
    [Parameter(Mandatory=$true)][array]$SMTPRecipients,
    [Parameter(Mandatory=$true)][string]$SMTPServerNameOrIPAddress,
    [Parameter(Mandatory=$true)][string]$MessageSubject,
    [Parameter(Mandatory=$false)][string]$MessageBody,
    [Parameter(Mandatory=$false)][PSCredential]$Credentials,
    [Parameter(Mandatory=$false)][int]$Port = 25,
    [Parameter(Mandatory=$false)][string]$CustomTestMessageSubject = "Script Mail Message Object Test",
    [Parameter(Mandatory=$false)][string]$CustomTestMessageBody = "Test Worked!"
    )
    #Function Version 1.3
    Add-Type -TypeDefinition @"
        namespace MailMessage
        {
            public enum StatusCode 
            {
                None,
                Success,
                Failed
            }
        }
"@
    
    if([string]::IsNullOrWhiteSpace($CustomTestMessageSubject))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageSubject"
    }
    if([string]::IsNullOrWhiteSpace($CustomTestMessageBody))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageBody"
    }
    
    $params = @{
        To = $SMTPRecipients
        From = $SMTPSender
        SmtpServer = $SMTPServerNameOrIPAddress
        Port = $Port
        Subject = $CustomTestMessageSubject
        Body = $CustomTestMessageBody
    }
    
    if([PSCredential]::Empty -ne $Credentials -and 
        $Credentials -ne $null)
    {
        $params.Add("Credential", $Credentials)
    }
    
    try 
    {
        Send-MailMessage @params -ErrorAction Stop
    }
    catch 
    {
        throw
    }
    
    #Passed sending the message, going to build the object 
    $params["Subject"] = $MessageSubject
    if([string]::IsNullOrWhiteSpace($MessageBody))
    {
        $params.Remove("Body")
    }
    else 
    {
        $params["Body"] = $MessageBody
    }
    
    
    $mailObject = New-Object -TypeName PSCustomObject 
    $mailObject | Add-Member -MemberType NoteProperty -Name "Parameters" -Value $params
    $mailObject | Add-Member -MemberType NoteProperty -Name "Exception" -Value ([string]::Empty)
    $mailObject | Add-Member -MemberType NoteProperty -Name "Success" -Value $true 
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "SendMail" -Value {
    
        $success = $true 
        $params = $this.Parameters 
        try 
        {
            Send-MailMessage @params -ErrorAction Stop 
        }
        catch 
        {
            $Success = $false 
            $this.Exception = $Error[0].Exception
        }
        if($success)
        {
            return [MailMessage.StatusCode]::Success
        }
        else 
        {
            return [MailMessage.StatusCode]::Failed
        }
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageBodyTypeArray" -Value {
        param(
        [array]$BodyArray 
        )
        
        $bodyString = [string]::Empty
        foreach($line in $BodyArray)
        {
            $bodyString += $line
            $bodyString += "`n"
        }
        $this.UpdateMessageBody($bodyString)
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageBody" -Value {
        param(
        [string]$Body
        )
        [hashtable]$params = $this.Parameters
        $bodyNullEmpty = $false 
        if([string]::IsNullOrWhiteSpace($Body))
        {
            $bodyNullEmpty = $true  
        }
        if($params.ContainsKey("Body"))
        {
            if($bodyNullEmpty)
            {
                $params.Remove("Body") 
            }
            else 
            {
                $params["Body"] = $Body
            }
        }
        else 
        {
            if($bodyNullEmpty)
            {
                return 
            }
            $params.Add("Body", $Body)     
        }
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageSubject" -Value {
        param(
        [string]$MessageSubject
        )
        if([string]::IsNullOrWhiteSpace($MessageSubject))
        {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide MessageSubject"
        }
        $params = $this.Parameters 
        $params["Subject"] = $MessageSubject
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageSmtpServer" -Value {
        param(
        [string]$SmtpServer
        )
        if([string]::IsNullOrEmpty($SmtpServer))
        {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide SmtpServer"
        }
        $this.Parameters["SmtpServer"] = $SmtpServer
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "GetMessageSmtpServer" -Value {
        
        return $this.Parameters["SmtpServer"]
    }
    
    $mailObject | Add-Member -MemberType ScriptMethod -Name "GetExceptionReason" -Value {
        return $this.Exception
    }
    
    return $mailObject 
    }
# End Function New-MailMessageObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Confirm-Administrator/Confirm-Administrator.ps1
Function Confirm-Administrator {
    #Function Version 1.1
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
    if($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))
    {
        return $true 
    }
    else 
    {
        return $false 
    }
}
# End Function Confirm-Administrator


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-PerformanceThresholdCounters/Get-PerformanceThresholdCounters.ps1
Function Get-PerformanceThresholdCounters {
[CmdletBinding()]
[OutputType([Hashtable])]
param(
[string]$PerformanceCounter,
[array]$Servers = @($env:COMPUTERNAME),
[double]$AverageThreshold,
[double]$MaxThreshold,
[string]$ThresholdType,
[System.Management.Automation.ActionPreference]$ActionPreference = "SilentlyContinue"
)
#Function Version 1.0
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>
<#
TODO: 
- Add an instance filter option
#>

Write-VerboseWriter("Calling: Get-PerformanceThresholdCounters")
Write-VerboseWriter("Passed: [string]PerformanceCounter: {0} | [double]AverageThreshold: {1} | [double]MaxThreshold: {2} | [string]ThresholdType: {3} | [ActionPreference]ActionPreference: {4}" -f `
    $PerformanceCounter, 
    $AverageThreshold, 
    $MaxThreshold, 
    $ThresholdType, 
    $ActionPreference)
Function Get-PerformanceThresholdCounterObject {
    $obj = New-Object PSCustomObject 
    $obj | Add-Member -MemberType NoteProperty -Name "AverageThreshold" -Value $AverageThreshold
    $obj | Add-Member -MemberType NoteProperty -Name "MaxThreshold" -Value $MaxThreshold
    $obj | Add-Member -MemberType NoteProperty -Name "ThresholdType" -Value $ThresholdType
    return $obj 
}

########## Parameter Binding Exceptions ##############
if([string]::IsNullOrEmpty($PerformanceCounter) -or
    $PerformanceCounter.StartsWith("\"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounter. Can not be null or empty and must not start with a '\'." 
}
if([string]::IsNullOrEmpty($ThresholdType) -or (
    $ThresholdType -ne "LessThan" -and 
    $ThresholdType -ne "GreaterThan"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ThresholdType. Accepted values are LessThan and GreaterThan." 
}

try 
{
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-VerboseWriter("Getting the counters....")
    $counterSamples = (Get-Counter -ComputerName $Servers -Counter $PerformanceCounter -ErrorAction $ActionPreference ).CounterSamples
    if($counterSamples.Count -eq 0)
    {
        throw "Failed to return any counters..." 
    } 
    Write-VerboseWriter("Finished getting the counters. Took {0} seconds to complete." -f ($stopWatch.Elapsed.TotalSeconds))
}
catch 
{
    $throwString = "Failed to run Get-Counter without any error. Error: '{0}'" -f ($Error[0].Exception)
    throw  $throwString
}

$returnHash = @{}
$currentSeconds = $stopWatch.Elapsed.TotalSeconds
$counterPaths = ($counterSamples | Group-Object Path).Name
Write-VerboseWriter("Took {0} seconds to group the counter paths." -f ($stopWatch.Elapsed.TotalSeconds - $currentSeconds))
$currentSeconds = $stopWatch.Elapsed.TotalSeconds
foreach($path in $counterPaths) 
{
    $returnHash.Add($path, (Get-PerformanceThresholdCounterObject))
}
$writeString = "Took {0} seconds to add {1} paths to the hash table." -f ($stopWatch.Elapsed.TotalSeconds - $currentSeconds), ($counterPaths.Count)
Write-VerboseWriter($writeString)
Write-VerboseWriter("Took {0} seconds to complete the Get-PerformanceThresholdCounters function" -f ($stopWatch.Elapsed.TotalSeconds))

return $returnHash 
}
# End Function Get-PerformanceThresholdCounters


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-TraceLogmanObject/New-TraceLogmanObject.ps1
Function New-TraceLogmanObject {
[CmdletBinding()]
param(
[string]$TraceLogmanName = "CustomTraceLogmanCapture",
[string]$LogFormat = "bincirc",
[int]$MaxSizeMB = 1024,
[string]$SaveFileDirectory,
[string]$Provider,
[string]$FileVersioning = "mmddhhmm",
[array]$NumberBuffers = @(16, 16), #Two int values required here
[int]$BufferSize = 1024, 
[string]$Mode = "globalsequence",
[array]$Servers,
[bool]$EventTraceSessionsEnabled = $true,
[bool]$OverwriteExistingFile = $false,
[bool]$VerboseEnabled = $false,
[object]$LoggerObject,
[scriptblock]$HostFunctionCaller,
[scriptblock]$VerboseFunctionCaller
)
#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>
<# 
TODO: 
    - Handle EventTraceSessionsEnabled being enabled with FileVersioning 
    - Include FileVersioning 
    - SaveFileDirectory needs to have smart logic for remote servers not having a valid path
    - Fix logic when we have EventTraceSessionsEnabled, on delete we don't check to see if the same name of trace is running/created that didn't use EventTraceSessions prior. 
#>

########## Parameter Binding Exceptions ##############

if([string]::IsNullOrEmpty($TraceLogmanName.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid TraceLogmanName" 
}
if([string]::IsNullOrEmpty($LogFormat) -or
    ($LogFormat -ne "bincirc" -and 
    $LogFormat -ne "bin"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat. Only accepted values are bincirc and bin." 
}
if($MaxSizeMB -lt 100)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSizeMB. Value must be greater than or equal to 100." 
}
if([string]::IsNullOrEmpty($SaveFileDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveFileDirectory" 
}
if(!([string]::IsNullOrEmpty($FileVersioning)) -and 
    ($FileVersioning -ne "mmddhhmm" -and 
    $FileVersioning -ne "nnnnnn"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileVersioning. Value must be mmddhhmm or nnnnnn" 
}
if($Servers -eq $null -or 
    $Servers.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers" 
}
if($NumberBuffers -eq $null -or 
    $NumberBuffers.Count -ne 2 -or 
    $NumberBuffers[0].GetType().Name -ne "Int32" -or 
    $NumberBuffers[1].GetType().Name -ne "Int32" -or 
    $NumberBuffers[0] -lt 16 -or 
    $NumberBuffers[1] -lt 16)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid NumberBuffers. Must be an array with to int32 values that are equal or greater than 16." 
}
if($BufferSize -lt 16)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BufferSize. Value must be greater than or equal to 16." 
}
if([string]::IsNullOrEmpty($Mode) -or 
    ($Mode -ne "globalsequence" -and 
    $Mode -ne "localsequence" -and 
    $Mode -ne "pagedmemory")) 
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Mode. Accepted values are globalsequence, localsequence, and pagedmemory." 
}
if([string]::IsNullOrEmpty($Provider))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider." 
}

Add-Type -TypeDefinition @"
    namespace TraceLogman
    {
        public enum StatusCode
        {
            None,
            Success,
            Failed
        }
        public enum Action 
        {
            Unknown,
            Start,
            Stop,
            Delete
        }
    }
"@

Function New-ServersStatus {
    $hasher = @{}
    foreach($server in $Servers)
    {
        $statusObj = New-Object PSCustomObject 
        $statusObj | Add-Member -MemberType NoteProperty -Name "DebugResults" -Value ([string]::Empty)
        $statusObj | Add-Member -MemberType NoteProperty -Name "LogmanStatusCode" -Value ([TraceLogman.StatusCode]::None)
        $hasher.Add($server,$statusObj) 
    }
    return $hasher
}

$traceLogmanObject = New-Object PSCustomObject 

$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "TraceLogmanName" -Value $TraceLogmanName
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "LogFormat" -Value $LogFormat 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "MaxSizeMB" -Value $MaxSizeMB 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "SaveFileDirectory" -Value $SaveFileDirectory
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "Provider" -Value $Provider 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "FileVersioning" -Value $FileVersioning 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "NumberBuffers" -Value $NumberBuffers
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "BufferSize" -Value $BufferSize 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "Mode" -Value $Mode 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "EventTraceSessionsEnabled" -Value $EventTraceSessionsEnabled 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "OverwriteExistingFile" -Value $OverwriteExistingFile
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "ServersStatus" -Value (New-ServersStatus)
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled 
$traceLogmanObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}
$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}

if($HostFunctionCaller -ne $null)
{
    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "ExecuteLogmanAction" -Value {
param(
[TraceLogman.Action]$Action = [TraceLogman.Action]::Unknown,
[array]$Servers = $this.Servers
)
    $this.WriteVerboseWriter("Calling ExecuteLogmanAction")
    $this.WriteVerboseWriter("Action: {0}" -f $Action)
    if($Action -eq [TraceLogman.Action]::Unknown)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Action in ExecuteLogmanAction" 
    }
    $logmanAction = [string]::Empty
    if($Action -eq [TraceLogman.Action]::Start)
    {
        $logmanAction = "Start"
    }
    elseif($Action -eq [TraceLogman.Action]::Stop)
    {
        $logmanAction = "Stop"
    }
    elseif($Action -eq [TraceLogman.Action]::Delete)
    {
        $logmanAction = "Delete"
    }
    $logman = $this.TraceLogmanName
    $failureOccurred = $false 
    $ets = ""
    if($this.EventTraceSessionsEnabled)
    {
        $ets = "-ets"
    }
    foreach($server in $Servers)
    {
        $this.WriteVerboseWriter("Runing logman against server: {0}" -f $server)
        [array]$results = logman $logmanAction $logman -s $server $ets
        $this.ServersStatus[$server].DebugResults = $results 
        $this.WriteVerboseWriter("Results from logman:")
        $this.WriteVerboseWriter($results)
        if(($results[-1]).Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Success
        }
        else 
        {
            $this.WriteVerboseWriter("Failed to do logman action on server: {0}" -f $server)
            $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
            $failureOccurred = $true 
        }
    }
    if($failureOccurred)
    {
        return [TraceLogman.StatusCode]::Failed
    }

    return [TraceLogman.StatusCode]::Success
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {
    if($this.EventTraceSessionsEnabled)
    {
        $this.WriteVerboseWriter("Can't start the logman trace when Event Trace Sessions is enabled. On Create it already does this. Going to return Success.")
        return [TraceLogman.StatusCode]::Success
    }    
    $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Start)
    return $status
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Stop)
    return $status
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "DeleteLogman" -Value {
    if($this.EventTraceSessionsEnabled)
    {
        $this.WriteVerboseWriter("Can't stop the logman trace when Event Trace Sessions is enabled. On Stop the data collector set is already removed. Going to return Success.")
        return [TraceLogman.StatusCode]::Success
    }
    $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Delete)
    return $status
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "CreateLogman" -Value {
    $servers = $this.Servers 
    [string]$path = $this.SaveFileDirectory
    if(!($path.EndsWith("\")))
    {
        $path = $path + "\"
    }
    $logman = $this.TraceLogmanName
    $fullFilePathStandard = $path + $logman + "_{0}.etl" 
    $format = $this.LogFormat 
    $maxSize = $this.MaxSizeMB 
    $provider = $this.Provider 
    $fileVersioning = $this.FileVersioning 
    $numBuffer1 = $this.NumberBuffers[0]
    $numBuffer2 = $this.NumberBuffers[1]
    $bufferSize = $this.BufferSize
    $mode = $this.Mode 
    $ets = ""
    if($this.EventTraceSessionsEnabled)
    {
        $ets = "-ets"
    }
    $overWrite = ""
    if($this.OverwriteExistingFile)
    {
        $overWrite = "-ow"
    }
    $failureOccurred = $false 
    foreach($server in $servers)
    {
        $this.WriteVerboseWriter("Creating logman on server: {0}" -f $server)
        $outputLocation = $fullFilePathStandard -f $server
        $this.WriteVerboseWriter("Output log location: {0}" -f $outputLocation)

        do
        {
            $createLoop = $false 
            $executeCommand = "logman create trace -n $logman -s $server $overWrite -o $outputLocation -p $provider -nb $numBuffer1 $numBuffer2 -bs $bufferSize -mode $mode -f $format -max $maxSize $ets"
            $this.WriteVerboseWriter("Full Command String: {0}" -f $executeCommand)
            [array]$results = Invoke-Expression $executeCommand #if we don't use Invoke-Expression here for some reason we get: Error: Element not found.; Failed to create the data collector set. Failing out the request.
            $this.WriteVerboseWriter("Results from logman:")
            $this.WriteVerboseWriter($results)
            $this.ServersStatus[$server].DebugResults = $results 
            if(($results[-1]).Trim() -eq "The command completed successfully.")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Success
            }
            elseif(($results[-1]).Trim() -eq "Data Collector Set already exists.")
            {
                $this.WriteVerboseWriter("Data Collector Already exists on server {0} re-creating it." -f $server)
                $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Delete, $server)
                if($status -eq [TraceLogman.StatusCode]::Success)
                {
                    $createLoop = $true 
                }
                else 
                {
                    $this.WriteVerboseWriter("Failed to re-create the data collector set. Failing out the request.")
                    $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
                    $failureOccurred = $true
                }
            }
            else 
            {
                $this.WriteVerboseWriter("Failed to create the data collector set. Failing out the request.")
                $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
                $failureOccurred = $true 
            }
        }while($createLoop)
    }
    if($failureOccurred)
    {
        return [TraceLogman.StatusCode]::Failed
    }
    return [TraceLogman.StatusCode]::Success
}

$traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "GetFailedStatusServers" -Value {
    $servers = $this.Servers
    $failedServers = @() 
    foreach($server in $servers)
    {
        if($this.ServersStatus[$server].LogmanStatusCode -eq [TraceLogman.StatusCode]::Failed)
        {
            $failedServers += $server 
        }
    }
    return $failedServers
}

return $traceLogmanObject 
}
# End Function New-TraceLogmanObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-ProcdumpManagerObject/New-ProcdumpManagerObject.ps1
Function New-ProcdumpManagerObject {
[CmdletBinding()]
param(
[string]$BinaryProcdumpExe = ".\procdump.exe",
[string]$ProcessName, 
[hashtable]$ProcessIDToServer,
[string]$DumpFolder,
[bool]$DumpWithMA = $true,
[bool]$DumpWithMP = $false, 
[int]$NumberOfDumps = 3,
[int]$SecondsWait = 30, 
[array]$Servers,
[bool]$VerboseEnabled = $false,
[object]$LoggerObject,
[scriptblock]$HostFunctionCaller,
[scriptblock]$VerboseFunctionCaller
)
#This Script requires Invoke-Command to be able to be run, even locally. 
#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>
<# 
#TODO List: 
- Add Verbose information 
- Add debug status info for dumping out the information when attemtping to execute procdump
#>


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if([string]::IsNullOrEmpty($BinaryProcdumpExe))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BinaryProcdumpExe." 
}
if(([string]::IsNullOrEmpty($ProcessName) -and
    ($ProcessIDToServer -eq $null)) -or 
    (!([string]::IsNullOrEmpty($ProcessName)) -and 
    ($ProcessIDToServer -ne $null)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ProcessName or ProcessIDToServer. Only one must be used." 
}
if(!([string]::IsNullOrEmpty($ProcessName)) -and 
    $ProcessName.EndsWith(".exe"))
{
    $ProcessName = $ProcessName.Replace(".exe","")
}
if([string]::IsNullOrEmpty($DumpFolder))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DumpFolder." 
}
if(!($DumpFolder.EndsWith("\")))
{
    $DumpFolder = $DumpFolder + "\"
}
if(($DumpWithMA -eq $true -and 
    $DumpWithMP -eq $true) -or 
    ($DumpWithMA -eq $false -and 
    $DumpWithMP -eq $false))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid dump type. Either DumpWithMA or DumpWithMP must be set to true." 
}
if($NumberOfDumps -eq $null -or 
    $NumberOfDumps -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid NumberOfDumps. Must be value greater than or equal to 1." 
}
if($SecondsWait -eq $null -or 
    $SecondsWait -lt 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SecondsWait. Must be a value greater than or equal to 0." 
}
if($Servers -eq $null -or 
    $Servers.Count -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BinaryProcdumpExe" 
}

Function Test-ValidProcdumpPath {
    foreach($server in $Servers)
    {
        [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {param($passedArg); $test = Test-Path $passedArg; return $test } -ArgumentList $BinaryProcdumpExe 
        if(!($result))
        {
            $throwString = "Failed to provide a valid path to procdump binary on server: {0}" -f $server
            throw [System.Management.Automation.ParameterBindingException] $throwString 
        }
    }
}

Function Test-ValidDumpPath {
    foreach($server in $Servers)
    {
        [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {param($passedArg); $test = Test-Path $passedArg; return $test} -ArgumentList $DumpFolder 
        if(!($result))
        {
            $throwString = "Failed to provide a valid path to dump out the data to on server: {0}" -f $server
            throw [System.Management.Automation.ParameterBindingException] $throwString 
        }
    }
}

Function Test-ValidHashTableKeys {
    foreach($server in $Servers)
    {
        if(!($ProcessIDToServer.ContainsKey($server)))
        {
            $throwString = "Failed to provide a key of {0} in the ProcessIDToServer hashtable" -f $server
            throw [System.Management.Automation.ParameterBindingException] $throwString 
        }
    }
}

Function Test-UsingProcessIDToServer {
    if($ProcessIDToServer -eq $null)
    {
        return $false 
    }
    return $true 
}

Test-ValidProcdumpPath
Test-ValidDumpPath
if(Test-UsingProcessIDToServer)
{
    Test-ValidHashTableKeys
}

$procdumpManagerObject = New-Object PSCustomObject 

$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "BinaryProcdumpExe" -Value $BinaryProcdumpExe
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "ProcessName" -Value $ProcessName
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "ProcessIDToServer" -Value $ProcessIDToServer
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "DumpFolder" -Value $DumpFolder 
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "DumpWithMA" -Value $DumpWithMA
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "NumberOfDumps" -Value $NumberOfDumps
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "SecondsWait" -Value $SecondsWait 
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled 
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject 
$procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "UsingProcessIDToServer" -Value (Test-UsingProcessIDToServer)
$procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}
$procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}

if($HostFunctionCaller -ne $null)
{
    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "ValidateProcessOnServers" -Value {
    if($this.UsingProcessIDToServer)
    {
        $processIdToServer = $this.ProcessIDToServer
        foreach($key in $processIdToServer.Keys)
        {
            $processId = $processIdToServer[$key]
            [bool]$result = Invoke-Command -ComputerName $key -ScriptBlock {param($passedArg); $getProcess = Get-Process -Id $passedArg -ErrorAction SilentlyContinue; if($getProcess -eq $null){return $false}; return $true } -ArgumentList $processId
            if(!($result))
            {
                #for now do a return false: TODO: return a failure result as it is possible that process could change while we are monitoring. 
                $writeHost = "Failed to get the process ID: {0} from Server: {1}" -f $processId, $key 
                $this.WriteHostWriter($writeHost)
                return $false
            }
        }
        return $true 
    }
    else 
    {
        $processName = $this.ProcessName
        foreach($server in $this.Servers)
        {
            [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {param($passedArg); $getProcess = Get-Process $passedArg -ErrorAction SilentlyContinue; if($getProcess -eq $null){return $false}; return $true } -ArgumentList $processName
            if(!($result))
            {
                $writeHost = "Failed to find the process name of '{0}' on server {1}" -f $processName, $server
                $this.WriteHostWriter($writeHost)
                return $false 
            }
        }
        return $true 
    }
}

$procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "DumpOnServer" -Value {
    param(
    [string]$Server 
    )
    if([string]::IsNullOrEmpty($Server) -or 
        (!($this.Servers.ToLower().Contains($Server.ToLower()))))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Server parameter"
    }

    if($this.UsingProcessIDToServer)
    {
        $processId = $this.ProcessIDToServer[$Server]
    }
    else 
    {
        $processId = $this.ProcessName 
    }
    if($this.DumpWithMA)
    {
        $dumpSwith = "-ma"
    }
    else 
    {
        $dumpSwith = "-mp"
    }
    $argList = New-Object PSCustomObject 
    $argList | Add-Member -MemberType NoteProperty -Name "BinaryProcdumpExe" -Value $this.BinaryProcdumpExe
    $argList | Add-Member -MemberType NoteProperty -Name "ProcessId" -Value $processId 
    $argList | Add-Member -MemberType NoteProperty -Name "DumpSwitch" -Value $dumpSwith 
    $argList | Add-Member -MemberType NoteProperty -Name "DumpFolder" -Value $this.DumpFolder
    $argList | Add-Member -MemberType NoteProperty -Name "NumberOfDumps" -Value $this.NumberOfDumps 
    $argList | Add-Member -MemberType NoteProperty -Name "Seconds" -Value $this.SecondsWait

    Invoke-Command -ComputerName $Server -ScriptBlock {
        param($passedArg) 
        $procDump = $passedArg.BinaryProcdumpExe
        $processId = $passedArg.ProcessId
        $dumpSwith = $passedArg.DumpSwitch
        $dumpFolder = $passedArg.DumpFolder 
        $numberOfDumps = $passedArg.NumberOfDumps
        $seconds = $passedArg.Seconds 
        & $procDump $dumpSwith $processId $dumpFolder -n $numberOfDumps -s $seconds -accepteula
    } -ArgumentList $argList 
}

return $procdumpManagerObject 
}
# End Function New-ProcdumpManagerObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-PerformanceLogmanObject/New-PerformanceLogmanObject.ps1
Function New-PerformanceLogmanObject {
[CmdletBinding()]
param(
[string]$PerformanceLogmanName = "CustomPerformanceCapture",
[string]$LogFormat = "bincirc",
[int]$MaxSizeMB = 4096,
[array]$PerformanceCounters,
[int]$SampleInterval = 2,
[string]$SaveFileDirectory,
[string]$FileVersioning = "mmddhhmm",
[array]$Servers,
[PSCredential]$RemoteCredentials,
[int]$IncreaseMaxSizeTimes = 20,
[int]$MaxStartUpdateLoop = 100,
[bool]$SystemDataCollectorSet = $false,
[bool]$VerboseEnabled = $false,
[object]$LoggerObject,
[scriptblock]$HostFunctionCaller,
[scriptblock]$VerboseFunctionCaller
)
#Function Version 1.3
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>
<#
TODO: 
- Be able to do none circular mode 
- Include File Versioning info 
- SaveFileDirectory needs to be better logic for checking to see if the path is valid on remote machines
#>
########## Parameter Binding Exceptions ##############

if([string]::IsNullOrEmpty($PerformanceLogmanName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceLogmanName" 
}
if([string]::IsNullOrEmpty($LogFormat) -or 
    ($LogFormat -ne "bincirc" -and 
    $LogFormat -ne "bin"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat. Only accepted values are bincirc and bin." 
}
if($MaxSizeMB -lt 512)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSizeMB. Value must be greater than or equal to 512." 
}
if((!($SystemDataCollectorSet)) -and 
    ($PerformanceCounters -eq $null -or 
    $PerformanceCounters.Count -eq 0))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounters" 
}
if($SystemDataCollectorSet -and 
    (!($PerformanceLogmanName.StartsWith("System\"))))
{
    $PerformanceLogmanName = "System\{0}" -f $PerformanceLogmanNames
}
if($SystemDataCollectorSet -and 
    $PerformanceLogmanName.Contains(" "))
{
    $PerformanceLogmanName = '"{0}"' -f $PerformanceLogmanName
}
if($SampleInterval -lt 1 -or 
    $SampleInterval -gt 30)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSizeMB. Value must be greater than or equal to 1 and less than or equal to 30." 
}
<#
if((!($SystemDataCollectorSet)) -and 
    ([string]::IsNullOrEmpty($SaveFileDirectory)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveFileDirectory" 
}
if((!($SystemDataCollectorSet)) -and 
    (!(Test-Path $SaveFileDirectory)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveFileDirectory. Path is not created." 
}
#>
if(!([string]::IsNullOrEmpty($FileVersioning)) -and 
    ($FileVersioning -ne "mmddhhmm" -and 
    $FileVersioning -ne "nnnnnn"))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileVersioning. Value must be mmddhhmm or nnnnnn" 
}
if($Servers -eq $null -or 
    $Servers.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers" 
}

Add-Type -TypeDefinition @"
    namespace PerformanceLogman
    {
        public enum StatusCode
        {
            None,
            Success,
            Failed
        }
        public enum Action 
        {
            Unknown,
            Start,
            Stop,
            Delete
        }
    }
"@


Function New-ServersStatus {
    $hasher = @{}
    foreach($server in $Servers)
    {
        $statusObj = New-Object PSCustomObject 
        $statusObj | Add-Member -MemberType NoteProperty -Name "DebugResults" -Value ([string]::Empty)
        $statusObj | Add-Member -MemberType NoteProperty -Name "LogmanStatusCode" -Value ([PerformanceLogman.StatusCode]::None)
        $hasher.Add($server,$statusObj) 
    }
    return $hasher
}

$performanceLogmanObject = New-Object PSCustomObject 

$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "PerformanceLogmanName" -Value $PerformanceLogmanName
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "LogFormat" -Value $LogFormat 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "MaxFileSizeMB" -Value $MaxSizeMB 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "PerformanceCounters" -Value $PerformanceCounters 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "SaveFileDirectory" -Value $SaveFileDirectory 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "FileVersioning" -Value $FileVersioning
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "RemoteCredentials" -Value $RemoteCredentials 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "IncreaseMaxSizeTimes" -Value $IncreaseMaxSizeTimes
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "MaxStartUpdateLoop" -Value $MaxStartUpdateLoop
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "ServersStatus" -Value (New-ServersStatus)
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "SystemDataCollectorSet" -Value $SystemDataCollectorSet
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled 
$performanceLogmanObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}
$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}

if($HostFunctionCaller -ne $null)
{
    $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "ExecuteLogmanAction" -Value {
param(
[PerformanceLogman.Action]$Action = [PerformanceLogman.Action]::Unknown,
[array]$Servers = $this.Servers
)
    $this.WriteVerboseWriter("Calling ExecuteLogmanAction")
    $this.WriteVerboseWriter("Action: {0}" -f $Action)
    if($Action -eq [PerformanceLogman.Action]::Unknown)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Action in ExecuteLogmanAction" 
    }
    $logmanAction = [string]::Empty
    if($Action -eq [PerformanceLogman.Action]::Start)
    {
        $logmanAction = "Start"
    }
    elseif($Action -eq [PerformanceLogman.Action]::Stop)
    {
        $logmanAction = "Stop"
    }
    elseif($Action -eq [PerformanceLogman.Action]::Delete)
    {
        $logmanAction = "Delete"
    }
    $logman = $this.PerformanceLogmanName
    $failureOccurred = $false
    $maxSize = $this.MaxFileSizeMB
    $updateCount = 0
    $startLoopCount = 0
    foreach($server in $Servers)
    {
        do 
        {
            $updateLoop = $false 
            if($this.RemoteCredentials -ne $null)
            {
                $this.WriteVerboseWriter("Executing this in an Invoke-Command script block.")
                $executeString = "logman $logmanAction $logman"
                [array]$results = Invoke-Command -ComputerName $server -ScriptBlock {param($ex); Invoke-Expression $ex} -Credential $this.RemoteCredentials -ArgumentList $executeString 
            }
            else 
            {
                [array]$results = logman $logmanAction $logman -s $server 
            }
            $this.ServersStatus[$server].DebugResults = $results
            $this.WriteVerboseWriter("Results from logman:")
            $this.WriteVerboseWriter($results)
            if(($results[-1]).Trim() -eq "The command completed successfully.")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
            }
            elseif($Action -eq [PerformanceLogman.Action]::Start -and 
                ($results[-1]).Trim() -eq "Unable to create the specified log file.")
            {
                $this.WriteVerboseWriter("Failed to start logman likely due to the size of the file on this system. Current size {0} MB" -f $maxSize)
                $updateLoop = $true 
                $updateCount++ 
                $maxSize++
                if($this.RemoteCredentials -ne $null)
                {
                    $executeString = "logman update counter $logman -max $maxSize" 
                    [array]$results = Invoke-Command -ComputerName $server -ScriptBlock {param($ex); Invoke-Expression $ex} -Credential $this.RemoteCredentials -ArgumentList $executeString 
                }
                else 
                {
                    [array]$results = logman update counter $logman -s $server -max $maxSize 
                }
                $this.ServersStatus[$server].DebugResults = $results
                if(($results[-1]).Trim() -eq "The command completed successfully.")
                {
                    $this.WriteVerboseWriter("Successfully updated the max size on the logman to {0} MB" -f $maxSize)
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
                }
                else 
                {
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                    $failureOccurred = $true 
                    $updateLoop = $false 
                    $this.WriteVerboseWriter("Failed to update the logman's max size. Going to fail out of this loop.")
                }
            }
            elseif($Action -eq [PerformanceLogman.Action]::Start -and 
                ($results[-1]).Trim() -eq "Cannot create a file when that file already exists." -and 
                $startLoopCount -lt $this.MaxStartUpdateLoop)
            {
                $this.WriteVerboseWriter("Failed to start logman because file already exists. Going to continue to restart this.")
                $updateLoop = $true
                $startLoopCount++
            }
            else 
            {
                $this.WriteVerboseWriter("Failed to do logman action on server: {0}" -f $server)
                $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                $failureOccurred = $true 
            }
        }while($updateLoop -and $updateCount -lt $this.IncreaseMaxSizeTimes)

    }
    if($failureOccurred)
    {
        return [PerformanceLogman.StatusCode]::Failed
    }
    return [PerformanceLogman.StatusCode]::Success
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {

    $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Start)
    return $status 
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    
    $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Stop)
    return $status 
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "DeleteLogman" -Value {
    
    if($this.SystemDataCollectorSet)
    {
        $this.WriteVerboseWriter("Can't delete a system data collector set.")
        return [PerformanceLogman.StatusCode]::Success
    }
    $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Delete)
    return $status 
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "CreateLogman" -Value {

    if($this.SystemDataCollectorSet)
    {
        $this.WriteVerboseWriter("Can't create a system data collector set.")
        return [PerformanceLogman.StatusCode]::Success
    }
    $servers = $this.Servers 
    [string]$path = $this.SaveFileDirectory
    if(!($path.EndsWith("\")))
    {
        $path = $path + "\"
    }
    $logman = $this.PerformanceLogmanName
    $fullFilePathStandard = $path + $logman + "_{0}_Circular" #TODO in case we aren't doing circular this needs to change 
    $format = $this.LogFormat
    $interval = $this.SampleInterval 
    $maxSize = $this.MaxFileSizeMB 
    $counters = $this.PerformanceCounters
    $failureOccurred = $false 
    foreach($server in $servers)
    {
        $this.WriteVerboseWriter("Creating logman on server: {0}" -f $server)
        $outputLocation = $fullFilePathStandard -f $server
        $this.WriteVerboseWriter("Output log location: {0}" -f $outputLocation)
        do 
        {
            $createLoop = $false 
            if($this.RemoteCredentials -ne $null)
            {
                $this.WriteVerboseWriter("Doing remote credential execution")
                $configLocation = "{0}{1}_Counters.config" -f $path, $logman
                $executeString = "logman create counter -n $logman -cf $configLocation -s $server -f $format -max $maxSize -si $interval -o $outputLocation"
                $this.WriteVerboseWriter("Execution String: {0}" -f $executeString)
                $args = New-Object PSCustomObject 
                $args | Add-Member -MemberType NoteProperty -Name "LogmanCommand" -Value $executeString 
                $args | Add-Member -MemberType NoteProperty -Name "Counters" -Value $counters 
                $args | Add-Member -MemberType NoteProperty -Name "ConfigLocation" -Value $configLocation 
                [array]$results = Invoke-Command -ComputerName $server -ScriptBlock {param($passedObject); $passedObject.Counters > $passedObject.ConfigLocation ;Invoke-Expression $passedObject.LogmanCommand} -Credential $this.RemoteCredentials -ArgumentList $args 
            }
            else 
            {
                $configLocation = "{0}{1}_Counters.config" -f $path, $logman
                $counters > $configLocation
                [array]$results = logman create counter -n $logman -cf $configLocation -s $server -f $format -max $maxSize -si $interval -o $outputLocation 
            }
            $this.WriteVerboseWriter("Results from logman:")
            $this.WriteVerboseWriter($results)
            $this.ServersStatus[$server].DebugResults = $results 
            if(($results[-1]).Trim() -eq "The command completed successfully.")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
            }
            elseif(($results[-1]).Trim() -eq "Data Collector already exists.")
            {
                $this.WriteVerboseWriter("Data Collector Already exists on server {0} re-creating it." -f $server)
                $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Delete, $server)
                if($status -eq [PerformanceLogman.StatusCode]::Success)
                {
                    $createLoop = $true 
                }
                else 
                {
                    $this.WriteVerboseWriter("Failed to re-create the data collector set. Failing out the request.")
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                    $failureOccurred = $true
                }
            }
            else 
            {
                $this.WriteVerboseWriter("Failed to create the data collector set. Failing out the request.")
                $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                $failureOccurred = $true 
            }
        }while($createLoop)

    }
    if($failureOccurred)
    {
        return [PerformanceLogman.StatusCode]::Failed
    }
    return [PerformanceLogman.StatusCode]::Success
}

$performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "GetFailedStatusServers" -Value {
    $servers = $this.Servers
    $failedServers = @() 
    foreach($server in $servers)
    {
        if($this.ServersStatus[$server].LogmanStatusCode -eq [PerformanceLogman.StatusCode]::Failed)
        {
            $failedServers += $server 
        }
    }

    return $failedServers
}

return $performanceLogmanObject 
}
# End Function New-PerformanceLogmanObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-LoggerObject/New-LoggerObject.ps1
Function New-LoggerObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogDirectory = ".",
[Parameter(Mandatory=$false)][string]$LogName = "Script_Logging",
[Parameter(Mandatory=$false)][bool]$EnableDateTime = $true,
[Parameter(Mandatory=$false)][bool]$IncludeDateTimeToFileName = $true,
[Parameter(Mandatory=$false)][int]$MaxFileSizeInMB = 10,
[Parameter(Mandatory=$false)][int]$CheckSizeIntervalMinutes = 10,
[Parameter(Mandatory=$false)][int]$NumberOfLogsToKeep = 10,
[Parameter(Mandatory=$false)][bool]$VerboseEnabled,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>

########################
#
# New-LoggerObject -- Template Functions
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
# End New-LoggerObject -- Template Functions
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

$loggerObject = New-Object pscustomobject 
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $LogDirectory
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $LogName
$loggerObject | Add-Member -MemberType NoteProperty -Name "FullPath" -Value $fullLogPath
$loggerObject | Add-Member -MemberType NoteProperty -Name "InstanceBaseName" -Value ([string]::Empty)
$loggerObject | Add-Member -MemberType NoteProperty -Name "EnableDateTime" -Value $EnableDateTime
$loggerObject | Add-Member -MemberType NoteProperty -Name "IncludeDateTimeToFileName" -Value $IncludeDateTimeToFileName
$loggerObject | Add-Member -MemberType NoteProperty -Name "MaxFileSizeInMB" -Value $MaxFileSizeInMB
$loggerObject | Add-Member -MemberType NoteProperty -Name "CheckSizeIntervalMinutes" -Value $CheckSizeIntervalMinutes
$loggerObject | Add-Member -MemberType NoteProperty -Name "NextFileCheckTime" -Value ((Get-Date).AddMinutes($CheckSizeIntervalMinutes))
$loggerObject | Add-Member -MemberType NoteProperty -Name "InstanceNumber" -Value 1
$loggerObject | Add-Member -MemberType NoteProperty -Name "NumberOfLogsToKeep" -Value $NumberOfLogsToKeep
$loggerObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled
$loggerObject | Add-Member -MemberType ScriptMethod -Name "ToLog" -Value ${Function:Write-ToLog}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

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
    $this.LogUpKeep()
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
    $this.LogUpKeep() 

}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "UpdateFileLocation" -Value{

    if($this.FullPath -eq $null)
    {
        if($this.IncludeDateTimeToFileName)
        {
            $this.InstanceBaseName = "{0}_{1}" -f $this.FileName, ((Get-Date).ToString('yyyyMMddHHmmss'))
            $this.FullPath = "{0}\{1}.txt" -f $this.FileDirectory, $this.InstanceBaseName
        }
        else 
        {
            $this.InstanceBaseName = "{0}" -f $this.FileName
            $this.FullPath = "{0}\{1}.txt" -f $this.FileDirectory, $this.InstanceBaseName
        }
    }
    else 
    {

        do{
            $this.FullPath = "{0}\{1}_{2}.txt" -f $this.FileDirectory, $this.InstanceBaseName, $this.InstanceNumber
            $this.InstanceNumber++
        }while(Test-Path $this.FullPath)
        $this.WriteVerbose("Updated to New Log")
    }
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "LogUpKeep" -Value {

    if($this.NextFileCheckTime -gt [System.DateTime]::Now)
    {
        return 
    }
    $this.NextFileCheckTime = (Get-Date).AddMinutes($this.CheckSizeIntervalMinutes)
    $this.CheckFileSize()
    $this.CheckNumberOfFiles()
    $this.WriteVerbose("Did Log Object Up Keep")
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "CheckFileSize" -Value {

    $item = Get-ChildItem $this.FullPath
    if(($item.Length / 1MB) -gt $this.MaxFileSizeInMB)
    {
        $this.UpdateFileLocation()
    }
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "CheckNumberOfFiles" -Value {

    $filter = "{0}*" -f $this.InstanceBaseName
    $items = Get-ChildItem -Path $this.FileDirectory | ?{$_.Name -like $filter}
    if($items.Count -gt $this.NumberOfLogsToKeep)
    {
        do{
            $items | Sort-Object LastWriteTime | Select -First 1 | Remove-Item -Force 
            $items = Get-ChildItem -Path $this.FileDirectory | ?{$_.Name -like $filter}
        }while($items.Count -gt $this.NumberOfLogsToKeep)
    }
}

$loggerObject.UpdateFileLocation()
try 
{
    "[{0}] : Creating a new logger instance" -f [System.DAteTime]::Now | Out-File ($loggerObject.FullPath) -Append
}
catch 
{
    throw 
}

return $loggerObject
}
# End Function New-LoggerObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-PerformanceCounterMonitorThresholdObject/New-PerformanceCounterMonitorThresholdObject.ps1
Function New-PerformanceCounterMonitorThresholdObject {
[CmdletBinding()]
param(
[hashtable]$PerformanceThresholdCounters,
[int]$SampleInterval = 1,
[int]$MaxSamples = 10,
[int]$SleepInSeconds = 0,
[int]$UpdateEveryXMinutes = 5,
[bool]$IncludeDateTimeOnUpdate = $true,
[object]$LoggerObject,
[scriptblock]$HostFunctionCaller,
[scriptblock]$VerboseFunctionCaller
)
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>
<#
This works remotely as well 
[hashtable]$PerformanceThresholdCounters
    [Key = \\serverName\logicaldisk(c:)\avg. disk sec/write]
        [value]
            [double]AverageThreshold
            [double]MaxThreshold
            [string]ThresholdType - GreaterThan/LessThan
#>

#Function Version 1.7
if($SampleInterval -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SampleInterval. Provide a value greater than 1."
}
if($MaxSamples -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSamples. Provide a value greater than 1."
}
if($UpdateEveryXMinutes -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid UpdateEveryXMinutes. Provide a value greater than 1"
}

if($PerformanceThresholdCounters -eq $null -or 
    $PerformanceThresholdCounters.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters."
} 

foreach($key in $PerformanceThresholdCounters.Keys)
{
    try 
    {
        Get-Counter -Counter $key -ErrorAction stop | Out-Null
    }
    catch 
    {
        $info = "Failed to provide valid key '{0}'. Error: {1}" -f $key, ($Error[0].Exception)
        throw [System.Management.Automation.ParameterBindingException] $info 
    }
    if([string]::IsNullOrEmpty($PerformanceThresholdCounters[$key].ThresholdType) -or 
        ($PerformanceThresholdCounters[$key].ThresholdType -ne "GreaterThan" -and 
        $PerformanceThresholdCounters[$key].ThresholdType -ne "LessThan"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a ThresholdType property with a string value of 'GreaterThan' or 'LessThan'"
    }
    if($PerformanceThresholdCounters[$key].AverageThreshold -eq $null -or 
        $PerformanceThresholdCounters[$key].AverageThreshold.Gettype().Name -ne "Double")
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a AverageThreshold property with a double type value." 
    }
    if($PerformanceThresholdCounters[$key].MaxThreshold -eq $null -or 
        $PerformanceThresholdCounters[$key].MaxThreshold.GetType().Name -ne "Double")
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceThresholdCounters object. Need to provide a MaxThreshold property with a double type value."
    }
}

Add-Type -TypeDefinition @"
    namespace PerformanceCounterMonitorThreshold
    {
        public enum StatusCode
        {
            None,
            Passed,
            ThresholdMet
        }
    }
"@ 

Function Get-Counters {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[System.Object]])]

    [System.Collections.Generic.List[System.Object]]$counterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    foreach($key in $PerformanceThresholdCounters.Keys)
    {
        $counterList.Add($key)
    }

    return $counterList
}

Function Get-ThresholdMetObjectDetails {
    $obj = New-Object PSCustomObject 
    $obj | Add-Member -MemberType NoteProperty -Name "Counter" -Value ([string]::Empty)
    $obj | Add-Member -MemberType NoteProperty -Name "MetValue" -Value ([double]0)
    $obj | Add-Member -MemberType NoteProperty -Name "Details" -Value ([string]::Empty)
    $obj | Add-Member -MemberType NoteProperty -Name "Type" -Value ([string]::Empty)
    return $obj
}

$perfMonitorObject = New-Object PSCustomObject 

$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "PerformanceThresholdCounters" -Value $PerformanceThresholdCounters
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "MaxSamples" -Value $MaxSamples
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepInSeconds" -Value $SleepInSeconds
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "Counters" -Value (Get-Counters)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "IncludeDateTimeOnUpdate" $IncludeDateTimeOnUpdate
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetDetails" -Value ([string]::Empty)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetObjectDetails" -Value (Get-ThresholdMetObjectDetails)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

if($HostFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

#Master Template https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-PerformanceCounterMinMaxAverageCorrectly/Get-PerformanceCounterMinMaxAverageCorrectly.ps1
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetPerformanceCounterMinMaxAverageCorrectly" -Value {

[CmdletBinding()]
param(
[object]$PerformanceCounterSamples
)

<#
Calculate Averages 
Average calculation for Average counters taken from these references:
https://msdn.microsoft.com/en-us/library/ms804010.aspx
https://blogs.msdn.microsoft.com/ntdebugging/2013/09/30/performance-monitor-averages-the-right-way-and-the-wrong-way/

[arrayOrList]PerformanceCounterSamples
    CookedValue
    RawValue
    TimeBase
    SecondValue
    CounterType
#>
    
    #Function Version 1.0
    if($PerformanceCounterSamples -eq $null -or 
        $PerformanceCounterSamples.Count -le 1)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounterSamples. Provide more than 1 sample as well."
    }

    $min = [int64]::MaxValue
    $max = [int64]::MinValue

    foreach($sample in $PerformanceCounterSamples)
    {
        if($sample.CookedValue -lt $min) {$min = $sample.CookedValue}
        if($sample.CookedValue -gt $max) {$max = $sample.CookedValue}
    }

    if($PerformanceCounterSamples[0].CounterType -like "AverageTimer*")
    {
        $numTicksDiff = $PerformanceCounterSamples[-1].RawValue - $PerformanceCounterSamples[0].RawValue
        $frequency = $PerformanceCounterSamples[-1].TimeBase
        $numOpsDif = $PerformanceCounterSamples[-1].SecondValue
        if($frequency -ne 0 -and $numTicksDiff -ne 0 -and $numOpsDif -ne 0)
        {
            $avg = (($numTicksDiff/ $frequency) / $numOpsDif)
        }
        else 
        {
            $avg = 0
        }
    }
    else 
    {
        $avg = ($PerformanceCounterSamples | Measure-Object -Property CookedValue -Average).Average
    }

    $minMaxAvgObj = New-Object PSCustomObject

    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Min" -Value $min
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Max" -Value $max
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Avg" -Value $avg

    return $minMaxAvgObj
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {

    if([DateTime]::Now -gt $this.NextUpdateTime)
    {
        [DateTime]$dt = [DateTime]::Now
        if($this.IncludeDateTimeOnUpdate)
        {
            $this.WriteHostWriter("[{0}] : Everything is passing checks thus far..." -f $dt)
        }
        else 
        {
            $this.WriteHostWriter("Everything is passing checks thus far...")
        }
        $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
    }
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetData" -Value {
    $measure = Measure-Command{$results = (Get-counter -Counter $this.Counters -SampleInterval $this.SampleInterval -MaxSamples $this.MaxSamples).CounterSamples | Group-Object Path}
    $this.WriteVerboseWriter("Took {0} seconds to get the data" -f $measure.TotalSeconds)
    return $results
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetMonitorResults" -Value {
    
    $results = $this.GetData()
    foreach($counterResults in $results)
    {
        $counterName = $counterResults.Name 
        $counterPassedObj = $this.PerformanceThresholdCounters[$counterName]
        $minMaxAvgResults = $this.GetPerformanceCounterMinMaxAverageCorrectly($counterResults.Group)
        
        $thresholdType = ([string]::Empty)
        $thresholdValue = 0

        if($counterPassedObj.ThresholdType -eq "GreaterThan")
        {
            if($minMaxAvgResults.Max -ge $counterPassedObj.MaxThreshold)
            {
                $details = "Met max spike threshold. Current max spike is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Max, $counterPassedObj.MaxThreshold, $counterName
                $thresholdType = "GreaterThanMax"
                $thresholdValue = $minMaxAvgResults.Max
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -ge $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdType = "GreaterThanAvg"
                $thresholdValue = $minMaxAvgResults.Avg 
                $thresholdMet = $true 
            }
        }
        elseif($counterPassedObj.ThresholdType -eq "LessThan")
        {
            if($minMaxAvgResults.Min -le $counterPassedObj.MaxThreshold)
            {
                $details = "Met min dip threshold. Current min dip is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Min, $counterPassedObj.MaxThreshold, $counterName
                $thresholdType = "LessThanMin"
                $thresholdValue = $minMaxAvgResults.Min
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -le $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdType = "LessThanAvg"
                $thresholdValue = $minMaxAvgResults.Avg
                $thresholdMet = $true 
            }   
        }
        if($thresholdMet)
        {
            $this.ThresholdMetDetails = $details
            $this.ThresholdMetObjectDetails.Counter = $counterName
            $this.ThresholdMetObjectDetails.MetValue = $thresholdValue
            $this.ThresholdMetObjectDetails.Details = $details 
            $this.ThresholdMetObjectDetails.Type = $thresholdType
            $this.WriteHostWriter($details)
            return [PerformanceCounterMonitorThreshold.StatusCode]::ThresholdMet
        }
    }
    $this.WriteUpdate()
    Start-Sleep $this.SleepInSeconds
    return [PerformanceCounterMonitorThreshold.StatusCode]::Passed
}

return $perfMonitorObject
}
# End Function New-PerformanceCounterMonitorThresholdObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-ScriptConfigFile/Import-ScriptConfigFile.ps1
Function Import-ScriptConfigFile {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ScriptConfigFileLocation,
[Parameter(Mandatory=$false)][string]$MainSplitLineValue = "~"
)

#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>

Write-VerboseWriter("Calling: Import-ScriptConfigFile")
Write-VerboseWriter("Passed: [string]ScriptConfigFileLocation: {0} | [string]MainSplitLineValue: {1}" -f $ScriptConfigFileLocation, $MainSplitLineValue)

Function Get-SystemConvertValue{
param(
[Parameter(Mandatory=$true)][string]$Value,
[Parameter(Mandatory=$true)][string]$Type
)
    Write-VerboseWriter("Calling: Get-SystemConvertValue")
    Write-VerboseWriter("Passed: [string]Value: {0} | [string]Type: {1}" -f $Value, $Type)
    if($Type -eq "int")
    {
        $variableValue = [System.Convert]::ToInt32($Value)
    }
    elseif($Type -eq "double")
    {
        $variableValue = [System.Convert]::ToDouble($Value)
    }
    elseif($Type -eq "int64")
    {
        $variableValue = [System.Convert]::ToInt64($Value)
    }

    return $variableValue
}

if(!(Test-Path $ScriptConfigFileLocation))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ScriptConfigFileLocation" 
}
$readContent = Get-Content $ScriptConfigFileLocation 

foreach($line in $readContent)
{
    Write-VerboseWriter("Working on line: {0}" -f $line)
    $splitInfo = $line.Split($MainSplitLineValue)
    $variableName = $splitInfo[0] 
    $fullVariableType = $splitInfo[1]
    $variableValue = $splitInfo[2]

    if($fullVariableType -like "GetContent*")
    {
        Write-VerboseWriter("Detected GetContent")
        if(Test-Path $variableValue)
        {
            $variableValue = Get-Content $variableValue
        }
        else 
        {
            Write-VerboseWriter("Failed to find {0}. Going to move on." -f $variableValue)
            continue 
        }
    }
    elseif($fullVariableType -like "array*")
    {
        Write-VerboseWriter("Detected array")
        $variableTypeSplit = $fullVariableType.Split("=")
        $type = $variableTypeSplit[1]
        $splitArrayValue = $variableTypeSplit[2]
        $variableValue = $variableValue.Split($splitArrayValue)
        if($type -ne "string")
        {
            Write-VerboseWriter("Determined array isn't a string type converting")
            $tempArray = @()
            foreach($value in $variableValue)
            {
                $tempArray += Get-SystemConvertValue -Value $value -Type $type 
            }

            $variableValue = $tempArray 
        }
    }
    elseif($fullVariableType -like "bool*")
    {
        Write-VerboseWriter("Detected boolean type")
        if($variableValue -eq "false")
        {
            $variableValue = $false 
        }
        else 
        {
            $variableValue = $true 
        }
    }
    elseif($fullVariableType -eq "int" -or 
    $fullVariableType -eq "double" -or 
    $fullVariableType -eq "int64")
    {
        Write-VerboseWriter("Detected a number type value")
        $variableValue = Get-SystemConvertValue -Value $variableValue -Type $fullVariableType 
    }
    Set-Variable -Name $variableName -Value $variableValue -Scope Script 
}

}
# End Function Import-ScriptConfigFile

    
    
########################
#
# End Template Functions
#
########################
    
    
########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

Function Invoke-FailScript {
    Write-Debug("Testing") -Debug
    exit #TODO add more logic here
}

Function Invoke-LogmanDataCollecotorAction {
param(
[Parameter(Mandatory=$true)][object]$LogmanDataCollector,
[Parameter(Mandatory=$true)][string]$Action,
[Parameter(Mandatory=$false)][bool]$ExitScript = $false,
[Parameter(Mandatory=$false)][bool]$ReturnStatus = $false
)
    $writeString = "Going to do action '{0}' on '{1}'" -f $Action, $LogmanDataCollector.FriendlyName
    $Script:Logger.WriteHost($writeString)
    if($LogmanDataCollector.$Action() -eq "Success")
    {
        $Script:Logger.WriteHost("Successfully did action '{0}'" -f $Action)
        if($ReturnStatus)
        {
            return $true
        }
    }
    else 
    {
        $writeString = "Failed to do action '{0}' on '{1}'." -f $Action, $LogmanDataCollector.FriendlyName
        $Script:Logger.WriteHost($writeString)
        if($ExitScript)
        {
            $Script:Logger.WriteHost("Failing out the script because of this failure.")
            Invoke-FailScript
        }
        if($ReturnStatus)
        {
            return $false
        }
    }

}

Function Start-DataCollectors {

    $Script:Logger.WriteVerbose("Calling Start-DataCollectors")
    $params = @{
        Action = "StartLogman"
        ExitScript = $true
    }
    if($ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryPerformanceData
    }
    if($ActiveDirectoryDiagnosticsEnabled -and 
        (!($ActiveDirectoryDiagnosticsAfterIssueOccursOnly)))
    {
        $Script:Logger.WriteVerbose("Going to start Active Directory Diagnostics. As ActiveDirectoryDiagnosticsAfterIssueOccursOnly is set to false.")
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryDiagnostics
    }
    else 
    {
        $Script:Logger.WriteHost("Not going to start Active Directory Diagnostics till after an issue is detected.")
    }
    if($ClientPerformanceDataCollectionSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientPerformanceData
    }
    if($ClientLDAPTracingEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientLDAPTracing
    }
}

Function Create-DataCollectors {
    $Script:Logger.WriteVerbose("Calling Create-DataCollectors") 
    $params = @{
        Action = "CreateLogman"
        ExitScript = $true
    }
    if($ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryPerformanceData
    }
    if($ClientPerformanceDataCollectionSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientPerformanceData
    }
    if($ClientLDAPTracingEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientLDAPTracing
    }
}

Function Stop-DataCollectors {
    $Script:Logger.WriteVerbose("Calling Stop-DataCollectors")
    $params = @{
        Action = "StopLogman"
        ExitScript = $false
    }
    if($ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryPerformanceData
    }
    if($ActiveDirectoryDiagnosticsEnabled -and 
        ((!($ActiveDirectoryDiagnosticsAfterIssueOccursOnly)) -or 
            $StopDataCollectors))
    {
        $Script:Logger.WriteVerbose("Going to stop Active Directory Diagnostics. As ActiveDirectoryDiagnosticsAfterIssueOccursOnly is set to false.")
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryDiagnostics
    }
    else 
    {
        $Script:Logger.WriteVerbose("Not going to stop Active Directory Diagnostics.")
    }
    if($ClientPerformanceDataCollectionSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientPerformanceData
    }
    if($ClientLDAPTracingEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientLDAPTracing
    }
}

Function Remove-DataCollectors {
    $Script:Logger.WriteVerbose("Calling Remove-DataCollectors")
    $params = @{
        Action = "DeleteLogman"
        ExitScript = $false
    }
    if($ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:activeDirectoryPerformanceData
    }
    if($ClientPerformanceDataCollectionSetEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientPerformanceData
    }
    if($ClientLDAPTracingEnabled)
    {
        Invoke-LogmanDataCollecotorAction @params -LogmanDataCollector $script:clientLDAPTracing
    }
}

Function Import-DataCollectors {
    $Script:Logger.WriteVerbose("Calling Import-DataCollectors")
    if($ClientProcdumpCollectionEnabled)
    {
        $Script:Logger.WriteVerbose("ClientProcdumpCollectionEnabled is enabled")
        $clientProcdumpParams = @{
            BinaryProcdumpExe = $ClientProcdumpBinaryLocation
            ProcessName = $ClientProcdumpProcessName
            DumpFolder = $ClientSaveAllDataPath
            Servers = $ClientServers
            LoggerObject = $Script:Logger
        }
        $Script:clientProcdumpManager = New-ProcdumpManagerObject @clientProcdumpParams
        $Script:Logger.WriteVerbose("Going to validate the setup of procdump.")
        if(!($Script:clientProcdumpManager.ValidateProcessOnServers()))
        {
            $Script:Logger.WriteHost("Failed to validate the procdump setup on the servers. Going to fail out the script.")
            exit
        }
        $Script:Logger.WriteVerbose("Validating procdump setup on the servers passed.")
    }
    if($ClientPerformanceDataCollectionSetEnabled)
    {
        $Script:Logger.WriteVerbose("ClientPerformanceDataCollectionSetEnabled is enabled")
        $clientPerformanceParams = @{
            PerformanceLogmanName = $ClientPerformanceDataCollectionSetLogmanName
            MaxSizeMB = $ClientPerformanceDataCollectionSetMaxSize
            PerformanceCounters = $ClientPerformanceDataCollectionSetCounters
            SampleInterval = $ClientPerformanceDataCollectionSetInterval
            Servers = $ClientServers
            SaveFileDirectory = $ClientSaveAllDataPath
            LoggerObject = $Script:Logger
        }
        $Script:clientPerformanceData = New-PerformanceLogmanObject @clientPerformanceParams
        $Script:clientPerformanceData | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value "Client Performance Data Collector Set"
    }
    if($ClientLDAPTracingEnabled)
    {
        $Script:Logger.WriteVerbose("ClientLDAPTracingEnabled is enabled")
        $clientLDAPParams = @{
            TraceLogmanName = $ClientLDAPTracingLogmanName
            SaveFileDirectory = $ClientSaveAllDataPath
            Provider = $ClientLDAPTracingProvider
            Servers = $ClientServers
            MaxSizeMB = $ClientLDAPTracingMaxSizeMB
            LoggerObject = $Script:Logger
        }
        $Script:clientLDAPTracing = New-TraceLogmanObject @clientLDAPParams
        $Script:clientLDAPTracing | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value "Client LDAP Tracing" 
    }
    if($ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        $Script:Logger.WriteVerbose("ActiveDirectoryPerformanceDataCollectorSetEnabled is enabled")
        $activeDirectoryPerformanceParams = @{
            PerformanceLogmanName = $ActiveDirectoryPerformanceDataCollectorSetLogmanName
            MaxSizeMB = $ActiveDirectoryPerformanceDataCollectorSetMaxSize
            PerformanceCounters = $ActiveDirectoryPerformanceDataCollectorSetCounters
            SampleInterval = $ActiveDirectoryPerformanceDataCollectorSetInterval
            Servers = $ActiveDirectoryServers
            SaveFileDirectory = $ActiveDirectorySavePath
            LoggerObject = $Script:Logger
        }
        if(!($ActiveDirectoryRemoteCredentialNotNeeded))
        {
            $activeDirectoryPerformanceParams.Add("RemoteCredentials", $Script:ActiveDirectoryRemoteCredentials)
        }
        $Script:activeDirectoryPerformanceData = New-PerformanceLogmanObject @activeDirectoryPerformanceParams
        $Script:activeDirectoryPerformanceData | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value "Active Directory Performance Data Collector Set" 
    }
    if($ActiveDirectoryDiagnosticsEnabled)
    {
        $Script:Logger.WriteVerbose("ActiveDirectoryDiagnosticsEnabled is enabled")
        $activeDirectoryDiagnosticsParams = @{
            PerformanceLogmanName = "System\Active Directory Diagnostics"
            Servers = $ActiveDirectoryServers
            SystemDataCollectorSet = $true 
            LoggerObject = $Script:Logger
        }
        if(!($ActiveDirectoryRemoteCredentialNotNeeded))
        {
            $activeDirectoryDiagnosticsParams.Add("RemoteCredentials",$Script:ActiveDirectoryRemoteCredentials)
        }
        $Script:activeDirectoryDiagnostics = New-PerformanceLogmanObject @activeDirectoryDiagnosticsParams
        $Script:activeDirectoryDiagnostics | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value "Active Directory Diagnostics Data Collector Set" 
    }
}

Function Update-SmtpServer{
param(
[string]$NotThisSmtpServer
)
    $Script:Logger.WriteVerbose("Calling Update-SmtpServer")
    $Script:Logger.WriteVerbose("Passed: [string]NotThisSmtpServer: {0}"-f $NotThisSmtpServer)
    if($MailNotificationMessageSubject -and 
        (!([string]::IsNullOrEmpty($NotThisSmtpServer))))
    {
        if($NotThisSmtpServer.ToLower() -eq $Script:mailMessage.GetMessageSmtpServer().ToLower())
        {
            if($MailNotificationSmtpServers.Count -gt 1)
            {
                foreach($server in $MailNotificationSmtpServers) 
                {
                    if($server.ToLower() -ne $NotThisSmtpServer.ToLower())
                    {
                        $writeString = "Updating the SMTP server from '{0}' to '{1}'}" -f $NotThisSmtpServer, $server
                        $Script:mailMessage.UpdateMessageSmtpServer($server)
                        $Script:Logger.WriteVerbose($writeString) 
                        break 
                    }
                }
            }
            else 
            {
                $Script:Logger.WriteVerbose("Failed to provide more options of SMTP Servers.")
            }
        }
    }   
}

Function Create-Folder {
param(
[string]$FolderPath
)
    if(!(Test-Path $FolderPath))
    {
        [System.IO.Directory]::CreateDirectory($FolderPath) | Out-Null
    }
}

Function Main {

    #Create Folders
    if($ClientProcdumpCollectionEnabled -or 
        $ClientPerformanceDataCollectionSetEnabled -or 
        $ClientLDAPTracingEnabled)
    {
        Invoke-Command -ScriptBlock ${Function:Create-Folder} -ArgumentList $ClientSaveAllDataPath -ComputerName $ClientServers
    }
    if($ActiveDirectoryDiagnosticsEnabled -or 
        $ActiveDirectoryPerformanceDataCollectorSetEnabled)
    {
        $params = @{
            ScriptBlock = ${Function:Create-Folder}
            ArgumentList = $ActiveDirectorySavePath
            ComputerName = $ActiveDirectoryServers
        }
        if(!($ActiveDirectoryRemoteCredentialNotNeeded))
        {
            $params.Add("Credential", $Script:ActiveDirectoryRemoteCredentials)
        }
        Invoke-Command @params
    }

    if($MonitorCounterTypeEnabled)
    {
        $Script:Logger.WriteVerbose("Monitor Based Off Counter type is enabled.")
        $params = @{
            PerformanceCounter = $MonitorCounterTypeCounterName
            ThresholdType = $MonitorCounterTypeThresholdType
            AverageThreshold = $MonitorCounterTypeAverageThreshold
            MaxThreshold = $MonitorCounterTypeMaxThreshold
            Servers = $ClientServers
        }
        $performanceThresholdCounters = Get-PerformanceThresholdCounters  @params

        $params = @{
            PerformanceThresholdCounters = $performanceThresholdCounters
            MaxSamples = $MonitorCounterTypeMaxSamples
            SleepInSeconds = $MonitorCounterTypeSleepInSeconds
            LoggerObject = $Script:Logger
            IncludeDateTimeOnUpdate = $false
        }
        $Script:performanceCounterMonitorThreshold = New-PerformanceCounterMonitorThresholdObject @params
    }
    else 
    {
        $Script:Logger.WriteHost("Failed to provide a valid Monitor type. Failing out the script.")
        Invoke-FailScript
    }

    if($MailNotificationEnabled)
    {
        [PSCredential]$mailCredentails = [PSCredential]::Empty
        if($MailNotificationRequireCredentials)
        {
            $Script:Logger.WriteHost("Please provide credentials that will be accepted by the SMTP server to accept the message.")
            $mailCredentails = Get-Credential 
        }
        $params = @{
            SMTPSender = $MailNotificationSender
            SMTPRecipients = $MailNotificationRecipients
            SMTPServerNameOrIPAddress = $MailNotificationSmtpServers[0]
            MessageSubject = $MailNotificationMessageSubject
            Credentials = $mailCredentails
        }
        try 
        {
            $Script:mailMessage = New-MailMessageObject @params
        }
        catch 
        {
            $Script:Logger.WriteHost("Failed to create the mail message object that is required to send messages. Failing out the script.")
            Invoke-FailScript
        }
        
    }

    Import-DataCollectors
    Create-DataCollectors

    $issuesOccurred = 0
    $waitTimeBetweenIssues = [datetime]::Now.AddMinutes(2)
    while($issuesOccurred -lt $IssueCount)
    {
        $updateTimer = [datetime]::Now
        Start-DataCollectors
        do {
            while($waitTimeBetweenIssues -gt [datetime]::Now)
            {
                if($updateTimer -lt [datetime]::Now)
                {
                    $updateTimer = [datetime]::Now.AddMinutes(1)
                    $Script:Logger.WriteHost("Waiting for '{0}' time to have passed before checking to see if there is an issue..." -f $waitTimeBetweenIssues)
                }
                Sleep 5
            }
        }while(($Script:performanceCounterMonitorThreshold.GetMonitorResults()) -eq [PerformanceCounterMonitorThreshold.StatusCode]::Passed)
        $issueStartTime = [datetime]::Now
        $details = $Script:performanceCounterMonitorThreshold.ThresholdMetObjectDetails
        $problemServer = $details.Counter.Substring(2, ($details.Counter.IndexOf("\", 2)-2))
        $writeString = "Counter: '{0}' Value: {1}" -f $details.Counter, $details.MetValue
        $Script:Logger.WriteHost("An issue has occurred on server {0}" -f ($problemServer))
        $Script:Logger.WriteHost($writeString)
        $issuesOccurred++ 
        $waitTimeToStopDataCollections = [datetime]::Now.AddMinutes($MinutesToContinueDataCollectionAfterIssueDetected)
        
        if($ActiveDirectoryDiagnosticsEnabled -and 
            $ActiveDirectoryDiagnosticsAfterIssueOccursOnly)
        {
            $Script:Logger.WriteHost("Starting Active Directory Diagnostics.")
            if((Invoke-LogmanDataCollecotorAction -LogmanDataCollector $Script:activeDirectoryDiagnostics -Action "StartLogman" -ReturnStatus $true))
            {
                if($ActiveDirectoryPerformanceDataCollectorSetEnabled -and 
                    $ActiveDirectoryPerformanceDataCollectorSetStopAfterDiagnosticsStarted)
                {
                    Invoke-LogmanDataCollecotorAction -LogmanDataCollector $Script:activeDirectoryPerformanceData -Action "StopLogman" 
                }
            }
            else 
            {
                $Script:Logger.WriteHost("Failed to start Active Directory Diagnostics.")
            }
        }
        if($ClientProcdumpCollectionEnabled)
        {
            $Script:Logger.WriteHost("Procdump Client Collection has been enabled. Going go to collect a dump from server {0}." -f $problemServer)
            $procdumpDisplayInfo = $Script:clientProcdumpManager.DumpOnServer($problemServer)
            $Script:Logger.WriteHost($procdumpDisplayInfo)
        }
        #Add custom stop data collectors here 
        <#
            - Stop LDAP tracing right after we are doing dumping the process
            - Stop the rest of the data collectors after provided time has passed 
            - execute minimize issue script if enabled 
            - wait duration before we start again
            - start tracing again.
        #>
        if($ClientLDAPTracingStopAfterIssueDetected -and 
            $ClientLDAPTracingEnabled)
        {
            Invoke-LogmanDataCollecotorAction -LogmanDataCollector $Script:clientLDAPTracing -Action "StopLogman" 
        }
        do{
            $Script:Logger.WriteHost("Waiting for '{0}' time to have passed..." -f $waitTimeToStopDataCollections)
            sleep 20
        }while($waitTimeToStopDataCollections -gt [DateTime]::Now)
        if((!($ClientLDAPTracingStopAfterIssueDetected)) -and 
            $ClientLDAPTracingEnabled)
        {
            Invoke-LogmanDataCollecotorAction -LogmanDataCollector $Script:clientLDAPTracing -Action "StopLogman" 
        }
        if($ActiveDirectoryDiagnosticsEnabled) 
        {   
            Invoke-LogmanDataCollecotorAction -LogmanDataCollector $Script:activeDirectoryDiagnostics -Action "StopLogman" 
        }
        if($ClientPerformanceDataCollectionSetEnabled)
        {
            Invoke-LogmanDataCollecotorAction -LogmanDataCollector $script:clientPerformanceData -Action "StopLogman"
        }
        if($MailNotificationEnabled)
        {
            Update-SmtpServer -NotThisSmtpServer $problemServer 
            $messageSubject = "{0} - Issue Time: {1} - Server {2}" -f $MailNotificationMessageSubject, $issueStartTime, $problemServer 
            $Script:mailMessage.UpdateMessageSubject($messageSubject) 
            $messageBody = "This issue was detected by '{0}' counter on the server with the value of {1}" -f $details.Counter, $details.MetValue
            $Script:mailMessage.UpdateMessageBody($messageBody) 
            if($Script:mailMessage.SendMail() -eq "Success")
            {
                $Script:Logger.WriteHost("Successfully sent the message for the issue detection.")
            }
            else 
            {
                $Script:Logger.WriteHost("Failed to send the message for the issue detection.")
            }

        }
        if($MinimizeIssueScriptEnabled)
        {
            $Script:Logger.WriteHost("Executing Minimize Issue Script...")
            if((Test-Path $MinimizeIssueScriptPath))
            {
                try 
                {
                    & $MinimizeIssueScriptPath $problemServer 
                }
                catch 
                {
                    $Script:Logger.WriteHost("Failed to execute minimize issue script: {0}" -f $MinimizeIssueScriptPath)
                    $Script:Logger.WriteHost("On Server: {0}" -f $problemServer)
                }
            }
            else 
            {
                $Script:Logger.WriteHost("Failed to find the script....")
            }
        }
        $waitTimeBetweenIssues = [datetime]::Now.AddMinutes($MinutesWaitDurationBetweenIssues)
    }
    $Script:Logger.WriteHost("Met Issue Count Limit. Removing Data Collectors.")
    if($MailNotificationEnabled)
    {
        $messageSubject = "{0} - Issue Count Reached" -f $MailNotificationMessageSubject
        $Script:mailMessage.UpdateMessageSubject($messageSubject)
        $Script:mailMessage.UpdateMessageBody("The Issue Count has been reached. Please restart the script again if you wish to choose so. Monitoring is no longer enabled.")
        if($Script:mailMessage.SendMail() -eq "Success")
        {
            $Script:Logger.WriteHost("Successfully sent the message.")
        }
        else 
        {
            $Script:Logger.WriteHost("Failed to send the message.")
        }
    }
    Remove-DataCollectors
}
$Script:RunningLocation = (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(!(Confirm-Administrator))
{
    Write-Host("Failed to run as an Administrator...")
    exit 
}
$Script:Logger = New-LoggerObject -LogName $scriptName -VerboseEnabled $Script:VerboseEnabled
if(Test-Path $scriptConfig)
{
    Import-ScriptConfigFile -ScriptConfigFileLocation $scriptConfig 
}

if($ClientProcdumpBinaryLocation.StartsWith(".\"))
{
    $Script:Logger.WriteVerbose("Updating ClientProcdumpBinaryLocation")
    $ClientProcdumpBinaryLocation = "{0}\{1}" -f $Script:RunningLocation , ($ClientProcdumpBinaryLocation.Replace(".\",""))
    $Script:Logger.WriteVerbose("New path: {0}" -f $ClientProcdumpBinaryLocation)
}
if($ClientSaveAllDataPath.StartsWith(".\"))
{
    $Script:Logger.WriteVerbose("Updating ClientSaveAllDataPath")
    $ClientSaveAllDataPath = "{0}\{1}" -f $Script:RunningLocation , ($ClientSaveAllDataPath.Replace(".\","")) 
    $Script:Logger.WriteVerbose("New path: {0}" -f $ClientSaveAllDataPath)
}

$Script:Logger.WriteHost($display)
Sleep 3
if(!($ActiveDirectoryRemoteCredentialNotNeeded) -and 
    ($ActiveDirectoryPerformanceDataCollectorSetEnabled -or 
    $ActiveDirectoryDiagnosticsEnabled))
{
    if($Script:ActiveDirectoryRemoteCredentials -eq $null)
    {
        $Script:Logger.WriteHost("Provide Active Directory Credentials: ")
        $Script:ActiveDirectoryRemoteCredentials = Get-Credential
    }
    try 
    {
        Invoke-Command -ComputerName $ActiveDirectoryServers[0] -ScriptBlock {Get-Process | Out-Null} -Credential $Script:ActiveDirectoryRemoteCredentials -ErrorAction Stop
    }   
    catch 
    {
        $Script:Logger.WriteHost("Failed to provide valid Active Directory Creds")
        exit 
    }     
}

if($StopDataCollectors)
{
    Import-DataCollectors 
    Stop-DataCollectors
    Remove-DataCollectors
    exit 
}

Main 
