<#
Name: Start-MonitorOnEvents.ps1
Author: David Paulson

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#>
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][bool]$EnableEmailNotification = $false,
[Parameter(Mandatory=$false)][string]$SMTPSender,
[Parameter(Mandatory=$false)][array]$SMTPRecipients,
[Parameter(Mandatory=$false)][string]$SMTPServerNameOrIPAddress = $ENV:COMPUTERNAME,
[Parameter(Mandatory=$false)][PSCredential]$MailCreds,
[Parameter(Mandatory=$false)][array]$Servers = @($ENV:COMPUTERNAME),
[Parameter(Mandatory=$false)][bool]$MDBFailureItemTagMonitorEnabled = $false,
[Parameter(Mandatory=$false)][array]$MDBFailureItemTags = @(38,39),
[Parameter(Mandatory=$false)][array]$ActiveDatabaseGUIDs,
[Parameter(Mandatory=$false)][string]$EventLogName = "Application",
[Parameter(Mandatory=$false)][int]$EventID = 2080,
[Parameter(Mandatory=$false)][int]$EventLevel = -1,
[Parameter(Mandatory=$false)][string]$EventTaskDisplayNameFilter,
[Parameter(Mandatory=$false)][string]$EventMessageFilter,
[Parameter(Mandatory=$false)][bool]$EventSusspendMonitorServerHostWriters = $false,
[Parameter(Mandatory=$false)][bool]$EventTimeUpdateIntervalInSeconds = 30,
[Parameter(Mandatory=$false)][bool]$EventTimeUpdateEnabled = $false,
[Parameter(Mandatory=$false)][bool]$EnableExtraTracing = $false,
[Parameter(Mandatory=$false)][array]$ExtraTraceConfigFileContent,
[Parameter(Mandatory=$false)][bool]$EnableExperfwizManager = $false,
[Parameter(Mandatory=$false)][int]$ExperfwizInterval = 1,
[Parameter(Mandatory=$false)][bool]$EnableNetshTrace = $false,
[Parameter(Mandatory=$false)][int]$NetshTraceMaxSize = 2048,
[Parameter(Mandatory=$false)][string]$NetshProviderString,
[Parameter(Mandatory=$false)][string]$NetshScenario = "netconnection",
[Parameter(Mandatory=$false)][int]$IssueLimit = 1,
[Parameter(Mandatory=$false)][string]$SaveAllDataPath = ((Get-Location).Path),
[Parameter(Mandatory=$false)][switch]$StopDataCollectors
)

$scriptVersion = 0.8

$display = @"

    Monitor on Event Log v{0}

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"@ -f $scriptVersion

$scriptConfig = "{0}\{1}.config" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), (Split-Path -Leaf $MyInvocation.MyCommand.Path)


########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}

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

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-ScriptConfigFile/Import-ScriptConfigFile.ps1
Function Import-ScriptConfigFile {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ScriptConfigFileLocation,
[Parameter(Mandatory=$false)][string]$MainSplitLineValue = "~"
)

#Function Version 1.0
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

    if($fullVariableType -like "array*")
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


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-MDBFailureItemTagMonitor/New-MDBFailureItemTagMonitor.ps1
Function New-MDBFailureItemTagMonitor {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][array]$TagIDs = @(38,39),
[Parameter(Mandatory=$false)][array]$DatabaseGUIDsToMonitor,
[Parameter(Mandatory=$false)][bool]$VerboseEnabled,
[Parameter(Mandatory=$false)][object]$LoggerObject,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.6
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-EventLogMonitorObject/New-EventLogMonitorObject.ps1
#>
#TODO: Add GetEventData() Method 
Add-Type -TypeDefinition @"
    namespace MDBFailureItemTag
    {
        public enum StatusCode
        {
            None,
            Passed,
            ConditionMet
        }
    }
"@ 

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($TagIDs -eq $null -and $TagIDs.Count -gt 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid TagIDs." 
}
if($DatabaseGUIDsToMonitor -ne $null -and $DatabaseGUIDsToMonitor.Count -gt 0)
{
    $FilterByDBGuidEnabled = $true
    $DatabaseGUIDsToMonitor = $DatabaseGUIDsToMonitor.ToUpper()
}
else 
{
    $FilterByDBGuidEnabled = $false 
}

$monitorEvents = New-EventLogMonitorObject -LogName "Microsoft-Exchange-MailboxDatabaseFailureItems/Operational" -EventID 1 -Servers @($env:COMPUTERNAME) -HostFunctionCaller $HostFunctionCaller -VerboseFunctionCaller $VerboseFunctionCaller -VerboseEnabled $VerboseEnabled
$monitorEvents.UpdateStartTime();

$failureItemTagMonitor = New-Object PSCustomObject
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "TagIDs" -Value $TagIDs
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "MonitorEventObject" -Value $monitorEvents 
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "FilterByDBGuidEnabled" -Value $FilterByDBGuidEnabled 
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "DatabaseGUIDsToMonitor" -Value $DatabaseGUIDsToMonitor
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "ConditionMetDB" -Value ([string]::Empty)
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

if($HostFunctionCaller -ne $null)
{
    $failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "MonitorEvents" -Value {

    $monitorStatus = $this.MonitorEventObject.MonitorServers()
    if($monitorStatus -eq [EventLogMonitor.StatusCode]::ConditionMet)
    {
        $eventsData = $this.MonitorEventObject.GetRawEventData() 
        foreach($eventData in $eventsData)
        {
            $doc = [xml]$eventData.ToXml()
            $tag = $doc.Event.UserData.EventXML.Tag 
            $dbGUID = $doc.Event.UserData.EventXML.DatabaseGuid.Trim(@('{', '}')).ToUpper()
            if($this.TagIDs.Contains($tag)) 
            {
                $this.WriteVerboseWriter("Ignoring failure item with tag: {0}" -f $tag)
                continue 
            }
            if($this.FilterByDBGuidEnabled -and 
            (!($this.DatabaseGUIDsToMonitor.Contains($dbGUID))))
            {
                $this.WriteVerboseWriter("Ignoring failure item for database: {0}" -f $dbGUID)
                continue 
            }
            $this.ConditionMetDB = $dbGUID 
            return [MDBFailureItemTag.StatusCode]::ConditionMet
        }
    }
    return [MDBFailureItemTag.StatusCode]::Passed
}

$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "ResetStatus" -Value {
    $this.MonitorEventObject.ResetStatus()
    $this.ConditionMetDB = [string]::Empty
}

$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "MonitorLoop" -Value {
    
    while($true)
    {
        if($this.MonitorEvents() -eq [MDBFailureItemTag.StatusCode]::ConditionMet)
        {
            return [MDBFailureItemTag.StatusCode]::ConditionMet
        }
        else 
        {
            Sleep 5
        }
    }
}

return $failureItemTagMonitor 
}

# End Function New-MDBFailureItemTagMonitor


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-ExperfwizManagerObject/New-ExperfwizManagerObject.ps1
Function New-ExperfwizManagerObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$ExperfwizDirectory = '.',
[Parameter(Mandatory=$false)][string]$ExperfwizName = "Experfwiz.ps1",
[Parameter(Mandatory=$false)][string]$SaveDirectory = ".",
[Parameter(Mandatory=$false)][int]$MaxFileSize = 4096,
[Parameter(Mandatory=$false)][int]$Interval,
[Parameter(Mandatory=$false)][bool]$EnableCircular = $true,
[Parameter(Mandatory=$false)][array]$Servers,
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
# New-ExperfwizManagerObject -- Template Functions
#
########################


########################
#
# End New-ExperfwizManagerObject -- Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

if([string]::IsNullOrWhiteSpace($ExperfwizDirectory) -or (!(Test-Path $ExperfwizDirectory)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExperfwizDirectory" 
}
$fullExperfwizPath = "{0}\{1}" -f $ExperfwizDirectory, $ExperfwizName
if(!(Test-Path $fullExperfwizPath))
{
    $throwString = "Failed to provide valid full path to {0} script" -f $ExperfwizName 
    throw [System.Management.Automation.ParameterBindingException] $throwString
}
if($MaxFileSize -lt 1024)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxFileSize. Must be equal or greater than 1024."
}
if($Interval -lt 1 -and $Interval -gt 60)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Interval. Must be value greater than 0 and less than 60."
}
if($Servers -eq $null -or $Servers.Count -eq 0)
{
    $Servers = @($env:COMPUTERNAME)
}
if($SaveDirectory -eq '.')
{
    $SaveDirectory = (Get-Location).Path
}

$experfwizManager = New-Object pscustomobject 
$experfwizManager | Add-Member -MemberType NoteProperty -Name "ExperfwizDirectory" -Value $ExperfwizDirectory
$experfwizManager | Add-Member -MemberType NoteProperty -Name "FullExperfwizPath" -Value $fullExperfwizPath 
$experfwizManager | Add-Member -MemberType NoteProperty -Name "SaveDirectory" -Value $SaveDirectory
$experfwizManager | Add-Member -MemberType NoteProperty -Name "MaxFileSize" -Value $MaxFileSize
$experfwizManager | Add-Member -MemberType NoteProperty -Name "Interval" -Value $Interval
$experfwizManager | Add-Member -MemberType NoteProperty -Name "EnableCircular" -Value $EnableCircular
$experfwizManager | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}


if($HostFunctionCaller -ne $null)
{
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {

    foreach($server in $this.Servers)
    {
        & $this.FullExperfwizPath -stop -server $server 
    }
}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "StartSuccessful" -Value {
    param(
    [string]$Server 
    )
    $results = logman Exchange_Perfwiz -s $Server 

    foreach($line in $results)
    {
        if($line.StartsWith("Status:"))
        {
            if($line.Contains("Running"))
            {
                return $true 
            }
            else 
            {
                return $false 
            }
        }
    }

}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "Start" -Value {

    foreach($server in $this.Servers)
    {
        $attempts = 0 
        $maxAttempts = 10 
        [int]$maxSize = $this.MaxFileSize 
        do{
            & $this.FullExperfwizPath -interval $this.Interval -circular -filepath $this.SaveDirectory -server $server -maxsize $maxSize -quiet
            $maxSize++
        }while((!($this.StartSuccessful($server))) -and $attempts -lt $maxAttempts)
    }

}

return $experfwizManager

}
# End Function New-ExperfwizManagerObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-ExtraLogmanObject/New-ExtraLogmanObject.ps1
Function New-ExtraLogmanObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogmanName = "ExchangeLogman",
[Parameter(Mandatory=$false)][string]$FileName,
[Parameter(Mandatory=$false)][int]$EtlFileSize = 400,
#[Parameter(Mandatory=$false)][string]$EtlCNF, # = "00:30:00", #TODO see if this is truly needed
[Parameter(Mandatory=$false)][string]$FileDirectory = "C:\Traces",
[Parameter(Mandatory=$false)][string]$Provider = "Microsoft Exchange Server 2010",
[Parameter(Mandatory=$false)][string]$AppendVersioningToFile = "mmddhhmm",
[Parameter(Mandatory=$false)][array]$Servers,
[Parameter(Mandatory=$false)][array]$ExtraTraceConfigFileContent
)

#Function Version 1.3
if([string]::IsNullOrEmpty($LogmanName.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName" 
}
if($EtlFileSize -lt 100 -or $EtlFileSize -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 1000"
}
if([string]::IsNullOrEmpty($FileDirectory.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileDirectory" 
}
if([string]::IsNullOrEmpty($Provider.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider" 
}
if([string]::IsNullOrEmpty($AppendVersioningToFile.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
}
if($Servers -eq $null -or $Servers.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers"
}
if($ExtraTraceConfigFileContent -eq $null -or $ExtraTraceConfigFileContent.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExtraTraceConfigFileContent"
}
if([string]::IsNullOrEmpty($FileName.Trim()))
{
    $FileName = $LogmanName
}

Add-Type -TypeDefinition @"
    namespace ExtraLogman
    {
        public enum StatusCode
        {
            None,
            Success,
            SingleServerFailure,
            AllFailure,
            Failed,
            DataCollectorExists,
            Running,
            Stopped,
            NotFound
        }
    }
"@ 

Function New-ServersStatusObject {
    $hasher = @{}
    foreach($server in $Servers)
    {
        $statusObject = New-Object PSCustomObject
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreatedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreatedStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StartedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StartedStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "LogmanStatus" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "LogmanStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "DeletedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "DeletedStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "ExtraConfigWasSaved" -Value ([ExtraLogman.StatusCode]::None)

        $hasher.Add($server,$statusObject)
    }
    return $hasher
}

#ToDo Add ability to test each server 
$logmanObject = New-Object PSCustomObject 
$logmanObject | Add-Member -MemberType NoteProperty -Name "TraceName" -Value $LogmanName
$logmanObject | Add-Member -MemberType NoteProperty -Name "ETLFileSize" -Value $EtlFileSize
$logmanObject | Add-Member -MemberType NoteProperty -Name "Provider" -Value $Provider
$logmanObject | Add-Member -MemberType NoteProperty -Name "AppendVersion" -Value $AppendVersioningToFile
$logmanObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $FileDirectory
$logmanObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $FileName
$logmanObject | Add-Member -MemberType NoteProperty -Name "ExtraTraceConfigFileContent" -Value $ExtraTraceConfigFileContent
$logmanObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$logmanObject | Add-Member -MemberType NoteProperty -Name "ServersStatus" -Value (New-ServersStatusObject)

#Save out .config file on all servers
$logmanObject | Add-Member -MemberType ScriptMethod -Name "SaveExtraConfigToAllServers" -Value {
    $failureCount = 0
    Function Save-ExtraLine {
    param(
    [Parameter(Mandatory=$true)][string]$Line 
    )
        $Line | Out-File -FilePath "C:\EnabledTraces.Config" -Encoding ascii -Append
    }

    $content = $this.ExtraTraceConfigFileContent
    New-Item -Path "C:\EnabledTraces.Config" -ItemType File -Force | Out-Null
    foreach($line in $content)
    {
        Save-ExtraLine $line
    }

    $servers = $this.Servers
    foreach($server in $servers)
    {
        if($server -ne $Env:COMPUTERNAME)
        {
            try 
            {
                Copy-Item "C:\EnabledTraces.Config" "\\$server\C$\EnabledTraces.Config" -ErrorAction Stop
                $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
            }
            catch 
            {
                $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }
        #creating the file shouldn't be an issue locally 
        else 
        {
            $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
        }
    }

    if($failureCount -ne 0)
    {
        return [ExtraLogman.StatusCode]::SingleServerFailure
    }
    return [ExtraLogman.StatusCode]::Success
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {
    $servers = $this.Servers
    $logman = $this.TraceName
    $failureCount = 0
    foreach($server in $servers)
    {
        [array]$results = logman start $logman -s $server
        $this.ServersStatus[$server].StartedResults = $results
        if(($results[-1]).Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }
    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    $servers = $this.Servers
    $logman = $this.TraceName
    $failureCount = 0 
    foreach($server in $servers)
    {
        [array]$results = logman stop $logman -s $server
        $this.ServersStatus[$server].StoppedResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "DeleteLogman" -Value {
    $servers = $this.Servers 
    $logman = $this.TraceName 
    $failureCount = 0
    foreach($server in $servers)
    {
        [array]$results = logman delete $logman -s $server
        $this.ServersStatus[$server].DeletedResults = $results
        $this.ServersStatus[$server].LogmanStatus = ([string]::Empty)
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "CreateLogman" -Value {
    $servers = $this.Servers 
    $path = $this.FileDirectory
    $fileName = $this.FileName
    $maxSize = $this.EtlFileSize
    $logman = $this.TraceName
    $appendVersion = $this.AppendVersion
    $provider = $this.Provider
    $failureCount = 0
    #Can't do hashtable to pass the params 
    foreach($server in $servers)
    {
        $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
        [array]$results = logman create trace $logman -max $maxSize -v $appendVersion -o $fullFileName -p $provider -s $server -bs 128 -f bincirc -mode globalsequence
        $this.ServersStatus[$server].CreatedResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        elseif($results[-1].Trim() -eq "Data Collector already exists.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::DataCollectorExists
            $failureCount++ #for now count this as a failure. 
        }
        else 
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "CheckLogmanStatus" -Value {
    $servers = $this.Servers 
    $logman = $this.TraceName 
    foreach($server in $servers)
    {
        [array]$results = logman $logman -s $server 
        
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
            $i = 2 
            if(-not ($results[$i].StartsWith("Status:")))
            {
                $i = 0 
                while($i -lt $results.count)
                {
                    if(($results[$i].StartsWith("Status:")))
                    {
                        break 
                    }
                    $i++ 
                }
            }
            $lineStatus = $results[$i].Replace("Status:","").Trim()
            $this.ServersStatus[$server].LogmanStatus = $lineStatus
            if($lineStatus -eq "running")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Running
            }
            elseif($lineStatus -eq "stopped")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Stopped
            }
        }
        else 
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::NotFound
            $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::None
        }
    }
    #For now, this should always return success 
    return ([ExtraLogman.StatusCode]::Success)
}

return $logmanObject 
}
# End Function New-ExtraLogmanObject


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


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-EventLogMonitorObject/New-EventLogMonitorObject.ps1
Function New-EventLogMonitorObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogName = "Application",
[Parameter(Mandatory=$false)][int]$EventID,
[Parameter(Mandatory=$false)][int]$Level = -1,
[Parameter(Mandatory=$false)][string]$TaskDisplayNameFilter,
[Parameter(Mandatory=$false)][string]$MessageFilter,
[Parameter(Mandatory=$false)][array]$Servers,
[Parameter(Mandatory=$false)][int]$WriteUpdateMinuteInterval = 5,
[Parameter(Mandatory=$false)][int]$SleepTime = 1,
[Parameter(Mandatory=$false)][int]$EventFilterStartTimeUpdateIntervalInSeconds = 30,
[Parameter(Mandatory=$false)][bool]$EventFilterStartTimeUpdateEnabled = $false,
[Parameter(Mandatory=$false)][bool]$SusspendMonitorServerHostWriters = $false,
[Parameter(Mandatory=$false)][bool]$VerboseEnabled = $false,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.5
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
#>
Add-Type -TypeDefinition @"
    namespace EventLogMonitor
    {
        public enum StatusCode
        {
            None,
            Passed,
            ConditionMet
        }
    }
"@ 

Function New-ServersStatusHashtable {
    $hasher = @{}
    foreach($server in $Servers)
    {
        $hasher.Add($server, ([EventLogMonitor.StatusCode]::Passed))
    }
    return $hasher
}
Function New-ServersEventDataHashtable {
    $hasher = @{}
    foreach($server in $Servers)
    {
        $hasher.Add($server,([string]::Empty))
    }
    return $hasher
}

########## Parameter Binding Exceptions ##############
if($EventID -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EventID. Needs to be a value greater than or equal to 1." 
}
if([string]::IsNullOrEmpty($LogName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogName." 
}
if($Servers -eq $null -or $Servers.count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers." 
}
if($WriteUpdateMinuteInterval -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid WriteUpdateMinuteInterval. Needs to be a value greater than or equal to 1." 
}
if($SleepTime -lt 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SleepTime. Needs to be a value greater than or equal to 0." 
}

$eventLogMonitorObject = New-Object PSCustomObject 
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "MessageFilter" -Value $MessageFilter
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "TaskDisplayNameFilter" -Value $TaskDisplayNameFilter
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $WriteUpdateMinuteInterval
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepTime" -Value $SleepTime
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "ServerStatus" -Value (New-ServersStatusHashtable)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "ServerEventData" -Value (New-ServersEventDataHashtable)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled 
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "SusspendMonitorServerHostWriters" -Value $SusspendMonitorServerHostWriters
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "EventFilterStartTimeUpdateEnabled" -Value $EventFilterStartTimeUpdateEnabled
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "EventFilterStartTimeUpdateIntervalInSeconds" -Value $EventFilterStartTimeUpdateIntervalInSeconds
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateFilterStartTime" -Value ([DateTime]::MinValue)
$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

$filterHashTable = @{
LogName = $LogName
ID = $EventID
StartTime = $StartTime
}
if($Level -ne -1)
{
    $filterHashTable.Add("Level",$Level)
}
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "FilterHashtable" -Value $filterHashTable

if($HostFunctionCaller -ne $null)
{
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "UpdateStartTime" -Value {
    param(
    [int]$SubtractSeconds = 0
    )
    $this.FilterHashtable["StartTime"] = (Get-Date).AddSeconds(-$SubtractSeconds).ToString("o")
    $this.NextUpdateFilterStartTime = (Get-Date).AddSeconds($this.EventFilterStartTimeUpdateIntervalInSeconds)
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {
    if([DateTime]::Now -gt $this.NextUpdateTime)
    {
        $this.WriteHostWriter(("[{0}] : Everything is passing checks thus far..." -f ([DateTime]$dt = [DateTime]::Now)))
        $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
    }
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "ResetStatus" -Value {
    foreach($server in $this.Servers)
    {
        $this.ServerEventData[$server] = [string]::Empty
        $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::Passed
    }
    #going to also update the start time and Next update Time
    $this.UpdateStartTime()
    $this.NextUpdateTime = [DateTime]::Now
}

$eventLogMonitorObject | Add-Member -MemberType  ScriptMethod -Name "GetConditionServers" -Value {
    $conditionServer = @() ##Needs to be array in case they don't reset the data 
    foreach($server in $this.Servers)
    {
        if($this.ServerStatus[$server] -eq [EventLogMonitor.StatusCode]::ConditionMet)
        {
            $conditionServer += $server
        }
    }
    return $conditionServer 
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetEventData" -Value {
    Function Get-StringArrayFromObjectDetails{
    param(
    [array]$Properties,
    [object]$EventData
    )
        $data = @()
        foreach($property in $Properties)
        {
            $data += "{0}: `t{1}" -f $property, ($EventData | Select-Object $property).$property
        }
        return $data
    }

    $conditionServer = $this.GetConditionServers() 
    $stringData = @("--Event Results--")
    foreach($server in $conditionServer)
    {
        $data = $this.ServerEventData[$server]
        $stringData += ("Server {0} Event Data" -f $server)
        $stringData += ""
        $stringData += Get-StringArrayFromObjectDetails -Properties @("MachineName","ID","ProviderName","TaskDisplayName", "LogName", "TimeCreated", "Message") -EventData $data
        $stringData += "--End Server Event Data--"
    }
    return $stringData 
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetRawEventData" -Value {
    $conditionServer = $this.GetConditionServers() 
    $events = @() 
    foreach($server in $conditionServer)
    {
        $events += $this.ServerEventData[$server]
    }
    return $events
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "MonitorServers" -Value {
    $eventOccurred = $false 
    foreach($server in $this.Servers)
    {
        [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
        $newEvents = Get-WinEvent -ComputerName $server -FilterHashtable $this.FilterHashTable -ErrorAction SilentlyContinue    
        $this.WriteVerboseWriter(("Took {0} seconds to attempt to get data from server {1}" -f $timer.Elapsed.TotalSeconds, $server))
        if($newEvents -eq $null)
        {
            $this.WriteVerboseWriter(("Server {0} didn't have any events" -f $server))
            continue; 
        }
        else 
        {
            if(!$this.SusspendMonitorServerHostWriters){ $this.WriteHostWriter(("Server {0} had event that we are looking for" -f $server))}
            if([string]::IsNullOrEmpty($this.MessageFilter) -and [string]::IsNullOrEmpty($this.TaskDisplayNameFilter))
            {
                $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::ConditionMet
                $this.ServerEventData[$server] = $newEvents
                $eventOccurred = $true 
                break;
            }
            else 
            {
                if(!$this.SusspendMonitorServerHostWriters){$this.WriteHostWriter(("Need to filter down the results some more..."))}
                foreach($event in $newEvents)
                {
                    $validEvent = $false 
                    if(!([string]::IsNullOrEmpty($this.MessageFilter)))
                    {
                        if($event.Message.Contains($this.MessageFilter))
                        {
                            $validEvent = $true 
                            $this.WriteVerboseWriter("Event met message filter")
                        }
                        else 
                        {
                            $this.WriteVerboseWriter("Event didn't meet message filter")
                            continue;
                        }
                    }
                    if(!([string]::IsNullOrEmpty($this.TaskDisplayNameFilter)))
                    {
                        if($event.TaskDisplayName -eq ($this.TaskDisplayNameFilter))
                        {
                            $validEvent = $true 
                            $this.WriteVerboseWriter("Event met task display name filter")
                        }
                        else 
                        {
                            $this.WriteVerboseWriter("Event didn't meet display name filter")
                            continue; 
                        }
                    }
                    if($validEvent)
                    {
                        $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::ConditionMet
                        $this.ServerEventData[$server] = $newEvents
                        $eventOccurred = $true 
                        break;
                    }
                }
            }
        }
    }

    if($eventOccurred)
    {
        return [EventLogMonitor.StatusCode]::ConditionMet
    }
    $this.WriteUpdate()
    return [EventLogMonitor.StatusCode]::Passed
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "MonitorLoop" -Value {
    param(
    [int]$DurationInMinutes = 0
    )

    if($DurationInMinutes -lt 0)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DurationInMinutes value. Needs to be a value 0 or greater. If 0 is provided, this loop will not break."
    }

    $breakLoopTime = [DateTime]::MaxValue
    if($DurationInMinutes -ne 0)
    {
        $breakLoopTime = ([datetime]::Now).AddMinutes($DurationInMinutes)
        $this.WriteVerboseWriter("Setting break loop time for {0}" -f $breakLoopTime)
    }
    else 
    {
        $this.WriteVerboseWriter("No break loop time is set. Will continue to run till condition is met.")
    }
    while([datetime]::Now -lt $breakLoopTime)
    {
        if($this.MonitorServers() -eq [EventLogMonitor.StatusCode]::ConditionMet)
        {
            return [EventLogMonitor.StatusCode]::ConditionMet
        }
        if($this.EventFilterStartTimeUpdateEnabled -and 
            [datetime]::Now -gt $this.NextUpdateFilterStartTime)
        {
            $this.UpdateStartTime(5)
        }
        Start-Sleep $this.SleepTime
    }
    $this.WriteVerboseWriter("No conditions were met during this loop")
    return [EventLogMonitor.StatusCode]::Passed
}
return $eventLogMonitorObject 
}
# End Function New-EventLogMonitorObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-NetshTraceObject/New-NetshTraceObject.ps1
Function New-NetshTraceObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$ServerList,
[Parameter(Mandatory=$false)][string]$Scenario = "netconnection",
[Parameter(Mandatory=$false)][string]$CustomProviderString, #Custom provider string needs to be done like this, otherwise PowerShell fails to find the provider: provider='{EB004A05-9B1A-11D4-9123-0050047759BC}' keywords=0x3fffffff level=0x7
[Parameter(Mandatory=$false)][string]$Persistent = "Yes",
[Parameter(Mandatory=$false)][string]$BaseFileName = "NetworkCapture",
[Parameter(Mandatory=$false)][string]$SaveDirectory = "C:\",
[Parameter(Mandatory=$false)][int]$MaxSize = 2048,
[Parameter(Mandatory=$false)][string]$Capture = "Yes", 
[Parameter(Mandatory=$false)][string]$Report = "Yes",
[Parameter(Mandatory=$false)][string]$Correlation = "No",
[Parameter(Mandatory=$false)][string]$FileMode = "circular",
[Parameter(Mandatory=$false)][string]$Overwrite = "Yes",
[Parameter(Mandatory=$false)][bool]$WriteVerboseData = $false,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.1
Add-Type -TypeDefinition @"
    namespace NetshTraceObject
    {
        public enum StatusCode
        {
            None,
            Success,
            Failed
        }
    }
"@ 

########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($this.VerboseFunctionCaller -eq $null -and $this.WriteVerboseData)
    {
        Write-Host $WriteString -ForegroundColor Cyan
    }
    elseif($this.WriteVerboseData)
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
##############################
#
#    Script Functions
#
##############################
Function New-ServerStatusHashtable {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server, ([NetshTraceObject.StatusCode]::None))
    }
    return $hasher
}

Function New-ServerStatusDetailsHashtables {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server, "None")
    }
    return $hasher
}

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
$usingCustomProviderString = $false 
if(!([string]::IsNullOrEmpty($CustomProviderString)))
{
    $usingCustomProviderString = $true
}
if([string]::IsNullOrEmpty($Scenario) -and (!($usingCustomProviderString)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Scenario"
}
if($Persistent -ne "Yes" -and $Persistent -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Persistent. Needs to be 'Yes' or 'no'" 
}
if([string]::IsNullOrEmpty($BaseFileName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BaseFileName"
}
if([string]::IsNullOrEmpty($SaveDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveDirectory"
}
if($MaxSize -lt 0 -or $MaxSize -gt (10 * 1MB))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSize. Provide a value between 0 and 10240 MB"
}
if($Capture -ne "Yes" -and $Capture -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Capture. Needs to be 'Yes' or 'No'"
}
if($Report -ne "Yes" -and $Report -ne "No" -and $Report -ne "Disabled")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Report. Needs to be 'Yes' or 'No' or 'Disabled'"
}
if($Correlation -ne "Yes" -and $Correlation -ne "No" -and $Correlation -ne "Disabled")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Correlation. Needs to be 'Yes' or 'No' or 'Disabled'"
}
if($FileMode -ne "Single" -and $FileMode -ne "Circular" -and $FileMode -ne "append")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileMode. Needs to be 'Single' or 'Circular' or 'Append'"
}
if($Overwrite -ne "Yes" -and $Overwrite -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Overwrite. Needs to be 'Yes' or 'No'"
}

$netshTraceObj = New-Object pscustomobject 

$netshTraceObj | Add-Member -MemberType NoteProperty -Name "ServerList" -Value $ServerList
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Scenario" -Value $Scenario
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "CustomProviderString" -Value $CustomProviderString
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "UsingCustomProvider" -Value $usingCustomProviderString 
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Persistent" -Value $Persistent
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "BaseFileName" -Value $BaseFileName
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "SaveDirectory" -Value $SaveDirectory
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "MaxSize" -Value $MaxSize
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Capture" -Value $Capture
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Report" -Value $Report 
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Correlation" -Value $Correlation
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "Overwrite" -Value $Overwrite
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "FileMode" -Value $FileMode
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "TraceFile" -Value ([string]::Empty)
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "ServerStatus" -Value (New-ServerStatusHashtable)
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "ServerStatusDetails" -Value (New-ServerStatusDetailsHashtables)
$netshTraceObj | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $WriteVerboseData
$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}
$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}


if($HostFunctionCaller -ne $null)
{
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}


$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartJobManager" -Value {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$ServersWithArguments,
[Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
[Parameter(Mandatory=$false)][string]$JobBatchName,
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJob = $false,
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJobInVerboseFunction, 
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJobInCorrectFunction,
[Parameter(Mandatory=$false)][bool]$NeedReturnData = $true
)

Function Write-ReceiveJobData {
param(
[Parameter(Mandatory=$true)][array]$ReceiveJobData
)
    $returnJob = [string]::Empty
    foreach($job in $ReceiveJobData)
    {
        if($job["Verbose"])
        {
            $this.WriteVerboseWriter($job["Verbose"])
        }
        elseif($job["Host"])
        {
            $this.WriteHostWriter($job["Host"])
        }
        elseif($job["ReturnObject"])
        {
            $returnJob = $job["ReturnObject"]
        }
        else 
        {
            $this.WriteVerboseWriter("Unable to determine the key for the return type.")    
        }
    }
    return $returnJob
}

Function Start-Jobs {
    $this.WriteVerboseWriter("Calling Start-Jobs")
    foreach($serverObject in $ServersWithArguments)
    {
        $server = $serverObject.ServerName
        $argumentList = $serverObject.ArgumentList
        $this.WriteVerboseWriter(("Starting job on server {0}" -f $server))
        Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock -ArgumentList $argumentList -AsJob -JobName $server | Out-Null
    }
}

Function Confirm-JobsPending {
    $jobs = Get-Job
    if($jobs -ne $null)
    {
        return $true 
    }
    return $false
}

Function Wait-JobsCompleted {
    [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
    $returnData = @{}
    while(Confirm-JobsPending)
    {
        $completedJobs = Get-Job | Where-Object {$_.State -ne "Running"}
        if($completedJobs -eq $null)
        {
            Start-Sleep 1 
            continue 
        }

        foreach($job in $completedJobs)
        {
            $receiveJobNull = $false 
            $jobName = $job.Name 
            $receiveJob = Receive-Job $job 
            Remove-Job $job
            if($receiveJob -eq $null)
            {
                $receiveJobNull = $True 
                $this.WriteHostWriter(("Job {0} didn't have any receive job data" -f $jobName))
            }
            if($DisplayReceiveJobInVerboseFunction -and(-not($receiveJobNull)))
            {
                $this.WriteHostWriter(("[JobName: {0}] : {1}" -f $jobName, $receiveJob))
            }
            elseif($DisplayReceiveJobInCorrectFunction -and (-not ($receiveJobNull)))
            {
                $returnJobData = Write-ReceiveJobData -ReceiveJobData $receiveJob
                if($returnJobData -ne $null)
                {
                    $returnData.Add($jobName, $returnJobData)
                }
            }
            elseif($DisplayReceiveJob -and (-not($receiveJobNull)))
            {
                $this.WriteHostWriter($receiveJob)
            }
            if($NeedReturnData -and (-not($DisplayReceiveJobInCorrectFunction)))
            {
                $returnData.Add($job.Name, $receiveJob)
            }
        }
    }
    $timer.Stop()
    $this.WriteVerboseWriter(("Waiting for jobs to complete took {0} seconds" -f $timer.Elapsed.TotalSeconds))
    if($NeedReturnData)
    {
        return $returnData
    }
    return $null 
}

[System.Diagnostics.Stopwatch]$timerMain = [System.Diagnostics.Stopwatch]::StartNew()

Start-Jobs
$data = Wait-JobsCompleted
$timerMain.Stop()
$this.WriteVerboseWriter(("Exiting: Start-JobManager | Time in Start-JobManager: {0} seconds" -f $timerMain.Elapsed.TotalSeconds))
if($NeedReturnData)
{
    return $data
}
return $null
}


$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StopTrace" -Value {
    
    $serversWithArguments = @()
    foreach($server in $this.ServerList)
    {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
        $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
        $serversWithArguments += $obj 
    }
    $this.WriteHostWriter(("[{0}] : Attempting to stop the netsh trace. This may take some time to complete." -f ([datetime]::Now)))
    $scriptBlock = [scriptblock]::Create("netsh trace stop")
    $results = $this.StartJobManager($serversWithArguments, $scriptBlock) 
    $allPassed = $true 
    foreach($server in $this.ServerList)
    {
        $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to stop the trace" -f $server))
        $data = $results[$server]
        $this.ServerStatusDetails[$server] = $data
        $serverSuccess = $false 
        $index = 0 
        if($data[0].Trim() -eq "There is no trace session currently in progress.")
        {
            $serverSuccess = $true 
        }
        elseif($data[3].Trim() -eq "Tracing session was successfully stopped.")
        {
            $serverSuccess = $true 
        }
        else 
        {
            while($index -lt $data.Count)
            {
                if($data[$index].Trim() -eq "Tracing session was successfully stopped.")
                {
                    $serverSuccess = $true 
                    break; 
                }
                $index++
            }
        }
        if($serverSuccess)
        {
            $this.WriteVerboseWriter(("Server {0} appears to have stopped the trace" -f $server))
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to have failed to stop the trace" -f $server))
            $this.WriteVerboseWriter($data)
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
            $allPassed = $false
        }
    }

    if($allPassed)
    {
        return [NetshTraceObject.StatusCode]::Success
    }

    return [NetshTraceObject.StatusCode]::Failed
}

$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartTrace" -Value {
    $serversWithArguments = @()
    foreach($server in $this.ServerList)
    {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
        $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
        $serversWithArguments += $obj 
    }

    $this.TraceFile = "{0}\{1}_{2}.etl" -f $this.SaveDirectory, $this.BaseFileName, ((Get-Date).ToString("yyyyMMddHHmmss"))
    $scriptBlockString = "Netsh trace start capture={0} maxsize={1} persistent={2} tracefile={3} correlation={4} overwrite={5} report={6}" -f $this.Capture,
    $this.MaxSize, $this.Persistent, $this.TraceFile, $this.Correlation, $this.Overwrite, $this.Report
    if($this.UsingCustomProvider)
    {
        $scriptBlockString = "{0} {1}" -f $scriptBlockString, $this.CustomProviderString
    }
    else 
    {
        $scriptBlockString = "{0} scenario={1}" -f $scriptBlockString, $this.Scenario
    }
    $this.WriteVerboseWriter(("Full netsh command: '{0}'" -f $scriptBlockString))
    $scriptBlock = [ScriptBlock]::Create($scriptBlockString)

    $results = $this.StartJobManager($serversWithArguments, $scriptBlock)
    $allPassed = $true 
    foreach($server in $this.ServerList)
    {
        $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to start the trace" -f $server))
        $data = $results[$server]
        $this.ServerStatusDetails[$server] = $data
        $index = 0
        if($data.count -lt 3)
        {
            #We either failed or have a netsh trace start need to fail them both out
            $index = -1
        }
        elseif($data[3].StartsWith("Status"))
        {
            $index = 3
        }
        else 
        {
            while($index -lt $data.count)
            {
                if($data[$index].StartsWith("Status"))
                {
                    break;
                }
                $index++
            }
            if($index -eq $data.count)
            {
                $index = -1
            }
        }
        if($index -eq -1 -or (-not($data[$index].Contains("Running"))))
        {
            $this.WriteHostWriter(("Server {0} appears to have failed to start the trace" -f $server))
            $this.WriteHostWriter($data)
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
            $allPassed = $false
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to have started the trace" -f $server))
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success 
        }
    }
    if($allPassed)
    {
        return [NetshTraceObject.StatusCode]::Success
    }
    else 
    {
        return [NetshTraceObject.StatusCode]::Failed
    }
}

$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "GetFailedServerStatusDetails" -Value {

    $stringReturnObject = @()
    foreach($server in $this.ServerList)
    {
        if($this.ServerStatus[$server] -eq [NetshTraceObject.StatusCode]::Failed)
        {
            $this.WriteVerboseWriter(("Serer {0} appears to have failed. Collecting the information" -f $server))
            $data = $this.ServerStatusDetails[$server]
            $stringReturnObject += "Server Failed Data: {0}" -f $server
            $stringReturnObject += $data
            $stringReturnObject += "--End--"
            $stringReturnObject += ""
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to not have failed." -f $server))
        }
    }
    return $stringReturnObject
}

return $netshTraceObj 
}
# End Function New-NetshTraceObject


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
#Function Version 1.2
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
[bool]$passedCreds = $false 
if([pscredential]::Empty -ne $Credentials -and $Credentials -ne $null)
{
    $passedCreds = $true 
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


$mailObject = New-Object -TypeName pscustomobject 
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

$mailObject | Add-Member -MemberType ScriptMethod -Name "GetExceptionReason" -Value {
    return $this.Exception
}

return $mailObject 
}
# End Function New-MailMessageObject



########################
#
# End Template Functions
#
########################


########################
#
# Script Functions
#
########################

Function Send-MailObject {
param(
[object]$SendMail
)
    if(!($EnableEmailNotification))
    {
        return 
    }

    $triesAttempts = 5
    $tries = 0 
    while($tries -lt $triesAttempts)
    {
        if($SendMail.SendMail() -eq [MailMessage.StatusCode]::Success)
        {
            break
        }
        Start-Sleep 10 
        $tries++ 
    }
    if($tries -eq $triesAttempts)
    {
        Write-HostWriter("Failed to send the mail message 5 times... stopping the script")
        exit 
    }
}

Function Start-DataCollections {

    if($EnableExtraTracing -and $Script:extraObject.StartLogman() -ne [ExtraLogman.StatusCode]::Success)
    {
        if($EnableEmailNotification)
        {
            $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to start extra trace -- stopping script")
            Send-MailObject -SendMail $Script:mailMessageObject
        }
        exit 
    }
    if($EnableNetshTrace -and $Script:netshTraceObject.StartTrace() -ne [NetshTraceObject.StatusCode]::Success) 
    {
        $MessageBody = $Script:netshTraceObject.GetFailedServerStatusDetails()
        $Script:netshTraceObject.StopTrace()
        if($EnableEmailNotification)
        {
            $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to start netsh trace -- stopping script")
            $Script:mailMessageObject.UpdateMessageBodyTypeArray($MessageBody)
            Send-MailObject -SendMail $Script:mailMessageObject
        }

        if($Script:extraObject.StopLogman() -ne [ExtraLogman.StatusCode]::Success)
        {
            if($EnableEmailNotification)
            {
                $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to stop extra trace.")
                $Script:mailMessageObject.UpdateMessageBody("Please stop the data collection ASAP to avoid extra from continuing to run on the systems")
                Send-MailObject -SendMail $Script:mailMessageObject
            }
        }
        exit 
    }
    if($EnableExperfwizManager)
    {
        $Script:experfwizManager.Start() 
    }
}

Function Stop-DataCollections {

    Write-HostWriter("Stopping the data collections")
    if($EnableExtraTracing -and $Script:extraObject.StopLogman() -ne  [ExtraLogman.StatusCode]::Success)
    {
        if($EnableEmailNotification)
        {
            $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to stop extra trace.")
            $Script:mailMessageObject.UpdateMessageBody("We attempted to stop extra trace after an issue was detected. Data could be overwritten in this data collection.")
            Send-MailObject -SendMail $Script:mailMessageObject
        }
    }
    if($EnableNetshTrace -and $Script:netshTraceObject.StopTrace() -ne [NetshTraceObject.StatusCode]::Success) 
    {
        #failed to stop the netsh trace for some reason 
        if($EnableEmailNotification)
        {
            $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to stop netsh trace")
            $Script:mailMessageObject.UpdateMessageBodyTypeArray($Script:netshTraceObject.GetFailedServerStatusDetails())
            Send-MailObject -SendMail $Script:mailMessageObject 
        }

    }
    if($EnableExperfwizManager)
    {
        Write-HostWriter("Waiting to stop experfwiz for 5 minutes from the time of the issue.")
        do{
            Sleep 10
        }while($Script:issueTime.AddMinutes(5) -gt [DateTime]::Now)
        $Script:experfwizManager.Stop() 
    }

}

Function Create-DataCollectionObjects {

    if($EnableEmailNotification)
    {
        $params = @{
            SMTPSender = $SMTPSender
            SMTPRecipients = $SMTPRecipients
            SMTPServerNameOrIPAddress = $SMTPServerNameOrIPAddress
            MessageSubject = "Monitor Events Script"
            CustomTestMessageSubject = "Monitor Events Script Test Of Send-Message"
        }
        if($MailCreds -ne $null)
        {
            $params.Add("Credentials",$MailCreds)
        }
        $Script:mailMessageObject = New-MailMessageObject @params
    }

    if($EnableNetshTrace)
    {
        $Script:netshTraceObject = New-NetshTraceObject -ServerList $Servers -SaveDirectory $SaveAllDataPath -Scenario $NetshScenario -CustomProviderString $NetshProviderString -MaxSize $NetshTraceMaxSize 
    }
    if($EnableExtraTracing)
    {
        $Script:extraObject = New-ExtraLogmanObject -FileDirectory $SaveAllDataPath -ExtraTraceConfigFileContent $ExtraTraceConfigFileContent -Servers $Servers
        if($Script:extraObject.SaveExtraConfigToAllServers() -ne [ExtraLogman.StatusCode]::Success)
        {
            if($EnableEmailNotification)
            {
                $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to save out extra config files to the servers --- stopping script")
                Send-MailObject -SendMail $Script:mailMessageObject
            }

            exit 
        }
        if($Script:extraObject.DeleteLogman() -ne [ExtraLogman.StatusCode]::Success)
        {
            #do nothing for now
        }
        if($Script:extraObject.CreateLogman() -ne [ExtraLogman.StatusCode]::Success)
        {
            if($EnableEmailNotification)
            {
                $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Failed to create Extra Trace -- stopping script")
                Send-MailObject -SendMail $Script:mailMessageObject
            }
            exit 
        }
    }
    if($MDBFailureItemTagMonitorEnabled)
    {
        $dbGUIDs = @() 
        foreach($db in $ActiveDatabaseGUIDs)
        {
            $dbGUIDs += $db.ToUpper() 
        }
        $Script:eventLogMonitorObject = New-MDBFailureItemTagMonitor -TagIDs $MDBFailureItemTags -DatabaseGUIDsToMonitor $dbGUIDs
    }
    else 
    {
        $Script:eventLogMonitorObject = New-EventLogMonitorObject -LogName $EventLogName -EventID $EventID -Servers $Servers -TaskDisplayNameFilter $EventTaskDisplayNameFilter -MessageFilter $EventMessageFilter -Level $EventLevel -SusspendMonitorServerHostWriters $EventSusspendMonitorServerHostWriters -EventFilterStartTimeUpdateEnabled $EventTimeUpdateEnabled -EventFilterStartTimeUpdateIntervalInSeconds $EventTimeUpdateIntervalInSeconds
    }

    if($EnableExperfwizManager)
    {
        $Script:experfwizManager = New-ExperfwizManagerObject -SaveDirectory $SaveAllDataPath -Interval $ExperfwizInterval -MaxFileSize 10240
    }

}

Function Main {
    Write-HostWriter $display
    if(!(Confirm-Administrator))
    {
        Write-HostWriter("Need to run the script as administrator.")
        exit 
    }

    Create-DataCollectionObjects
    $issueCount = 0 
    while($issueCount -lt $IssueLimit)
    {

        Start-DataCollections
        $Script:eventLogMonitorObject.ResetStatus()
        $Script:eventLogMonitorObject.MonitorLoop()
        $Script:issueTime = [Datetime]::Now
        Write-Host("Issue detected at {0}" -f $Script:issueTime)
        Stop-DataCollections
        if($EnableEmailNotification)
        {
            $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script Detected {0}" -f $Script:issueTime)
            $MessageBody = @("Issue event details: ")
            $MessageBody += $Script:eventLogMonitorObject.GetEventData()
            $Script:mailMessageObject.UpdateMessageBodyTypeArray($MessageBody)
            Send-MailObject -SendMail $Script:mailMessageObject 
        }
        $Script:eventLogMonitorObject.GetEventData()
        Write-HostWriter("Restarting the data collection process as issue count hasn't been met.")
        $issueCount++
    }

    if($EnableEmailNotification)
    {
        $Script:mailMessageObject.UpdateMessageSubject("Monitor Events Script -- Stopped Limit Reached")
        $Script:mailMessageObject.UpdateMessageBody(("Limit of {0} was reached. If you want to continue getting data, please restart the script" -f $IssueLimit))
        Send-MailObject -SendMail $Script:mailMessageObject 
    }

}


######### Stop Data Collectors ##############
if(Test-Path $scriptConfig)
{
    Import-ScriptConfigFile -ScriptConfigFileLocation $scriptConfig 
}

if($StopDataCollectors)
{   
    $netshTraceObject = New-NetshTraceObject -ServerList $Servers 
    $netshTraceObject.StopTrace()
    $Script:extraObject = New-ExtraLogmanObject -Servers $Servers -ExtraTraceConfigFileContent $ExtraTraceConfigFileContent
    $Script:extraObject.StopLogman()

    exit 
}


####### Check for Parameter Issues ##########
$failedString = "Failed to provide valid {0}."
if($EnableEmailNotification)
{
    if([string]::IsNullOrEmpty($SMTPSender))
    {
        throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPSender")
    }
    if([string]::IsNullOrEmpty($SMTPRecipients))
    {
        throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPRecipients")
    }
    if([string]::IsNullOrEmpty($SMTPServerNameOrIPAddress))
    {
        throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPServerNameOrIPAddress")
    }
}
if(-not(Test-Path -Path $SaveAllDataPath))
{
    throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SaveAllDataPath. Please provide a valid path.")
}

Main 
