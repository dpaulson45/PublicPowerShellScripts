Function New-MDBFailureItemTagMonitor {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][array]$TagIDs = @(38,39),
[Parameter(Mandatory=$false)][array]$MonitorOnlyDBs,
[Parameter(Mandatory=$false)][bool]$WriteVerboseData, 
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.2
#[System.Collections.Generic.List[System.Object]]$list = New-Object -TypeName System.Collections.Generic.List[System.Object]
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

########################
#
# Template Functions
#
########################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-EventLogMonitorObject/New-EventLogMonitorObject.ps1
Function New-EventLogMonitorObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogName = "Application",
[Parameter(Mandatory=$false)][int]$EventID,
[Parameter(Mandatory=$false)][array]$ServerList,
[Parameter(Mandatory=$false)][int]$UpdateEveryXMinutes = 5,
[Parameter(Mandatory=$false)][int]$SleepTime = 1,
[Parameter(Mandatory=$false)][bool]$WriteVerboseData = $false,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.2
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

########################
#
#   Functions
#
########################

Function New-ServersStatusHashtable {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server, ([EventLogMonitor.StatusCode]::Passed))
    }
    return $hasher
}
Function New-ServersEventDataHashtable {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server,([string]::Empty))
    }
    return $hasher
}

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

if($EventID -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EventID. Needs to be a value greater than or equal to 1." 
}
if([string]::IsNullOrEmpty($LogName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogName." 
}
if($ServerList -eq $null -or $ServerList.count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ServerList." 
}
if($UpdateEveryXMinutes -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid UpdateEveryXMinutes. Needs to be a value greater than or equal to 1." 
}
if($SleepTime -lt 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SleepTime. Needs to be a value greater than or equal to 0." 
}


$eventLogMonitorObject = New-Object pscustomobject 

$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "ServerList" -Value $ServerList
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "LogName" -Value $LogName
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "StartTime" -Value ([datetime]::MinValue)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepTime" -Value $SleepTime
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "ServerStatus" -Value (New-ServersStatusHashtable)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "ServerEventData" -Value (New-ServersEventDataHashtable)
$eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $WriteVerboseData 
$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}

if($HostFunctionCaller -ne $null)
{
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "UpdateStartTime" -Value {
    $this.StartTime = (Get-Date).ToString("o")
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {
    
    if([DateTime]::Now -gt $this.NextUpdateTime)
    {
        $this.WriteHostWriter(("[{0}] : Everything is passing checks thus far..." -f ([DateTime]$dt = [DateTime]::Now)))
        $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
    }
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "ResetStatus" -Value {
    foreach($server in $this.ServerList)
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
    foreach($server in $this.ServerList)
    {
        if($this.ServerStatus[$server] -eq [EventLogMonitor.StatusCode]::ConditionMet)
        {
            $conditionServer += $server
        }
    }
    return $conditionServer 
}

$eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetEventData" -Value {
    
    $conditionServer = $this.GetConditionServers() 

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
    foreach($server in $this.ServerList)
    {
        [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
        $newEvents = Get-WinEvent -ComputerName $server -FilterHashtable @{LogName=$this.LogName;StartTime=$this.StartTime;ID=$this.EventID} -ErrorAction SilentlyContinue    
        $this.WriteVerboseWriter(("Took {0} seconds to attempt to get data from server {1}" -f $timer.Elapsed.TotalSeconds, $server))
        if($newEvents -eq $null)
        {
            $this.WriteVerboseWriter(("Server {0} didn't have any events" -f $server))
            continue; 
        }
        else 
        {
            $this.WriteHostWriter(("Server {0} had event that we are looking for" -f $server))
            $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::ConditionMet
            $this.ServerEventData[$server] = $newEvents
            $eventOccurred = $true 
            break;
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
    [int]$LoopForXMinutes = 0
    )

    if($LoopForXMinutes -lt 0)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LoopForXMinutes value. Needs to be a value 0 or greater. If 0 is provided, this loop will not break."
    }

    $breakLoopTime = [DateTime]::MaxValue
    if($LoopForXMinutes -ne 0)
    {
        $breakLoopTime = ([datetime]::Now).AddMinutes($LoopForXMinutes)
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
        Start-Sleep $this.SleepTime
    }
    $this.WriteVerboseWriter("No conditions were met during this loop")
    return [EventLogMonitor.StatusCode]::Passed
}

return $eventLogMonitorObject 
}
# End Function New-EventLogMonitorObject



########################
#
# End Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($TagIDs -eq $null -and $TagIDs.Count -gt 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid TagIDs." 
}
if($MonitorOnlyDBs -ne $null -and $MonitorOnlyDBs.Count -gt 0)
{
    $MonitorOnlyDBsEnable = $true 
}
else 
{
    $MonitorOnlyDBsEnable = $false 
}

$monitorEvents = New-EventLogMonitorObject -LogName "Microsoft-Exchange-MailboxDatabaseFailureItems/Operational" -EventID 1 -ServerList @($env:COMPUTERNAME) -HostFunctionCaller $HostFunctionCaller -VerboseFunctionCaller $VerboseFunctionCaller
$monitorEvents.UpdateStartTime();

$failureItemTagMonitor = New-Object pscustomobject
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "TagIDs" -Value $TagIDs
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "MonitorEventObject" -Value $monitorEvents 
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "MonitorOnlyDBsEnable" -Value $MonitorOnlyDBsEnable 
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "MonitorOnlyDBs" -Value $MonitorOnlyDBs
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "ConditionMetDB" -Value ([string]::Empty)
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $WriteVerboseData
$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}

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
            if($this.MonitorOnlyDBsEnable -and 
            (!($this.MonitorOnlyDBs.Contains($dbGUID))))
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


return $failureItemTagMonitor 
}
