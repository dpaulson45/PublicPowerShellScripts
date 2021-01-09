Function New-EventLogMonitorObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$LogName = "Application",
        [Parameter(Mandatory = $false)][int]$EventID,
        [Parameter(Mandatory = $false)][string]$ProviderName,
        [Parameter(Mandatory = $false)][int]$Level = -1,
        [Parameter(Mandatory = $false)][string]$TaskDisplayNameFilter,
        [Parameter(Mandatory = $false)][string]$MessageFilter,
        [Parameter(Mandatory = $false)][array]$Servers,
        [Parameter(Mandatory = $false)][int]$WriteUpdateMinuteInterval = 5,
        [Parameter(Mandatory = $false)][int]$SleepTime = 1,
        [Parameter(Mandatory = $false)][int]$EventFilterStartTimeUpdateIntervalInSeconds = 30,
        [Parameter(Mandatory = $false)][bool]$EventFilterStartTimeUpdateEnabled = $false,
        [Parameter(Mandatory = $false)][bool]$SuspendMonitorServerHostWriters = $false,
        [Parameter(Mandatory = $false)][bool]$VerboseEnabled = $false,
        [Parameter(Mandatory = $false)][scriptblock]$HostFunctionCaller,
        [Parameter(Mandatory = $false)][scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
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
        foreach ($server in $Servers) {
            $hasher.Add($server, ([EventLogMonitor.StatusCode]::Passed))
        }
        return $hasher
    }
    Function New-ServersEventDataHashtable {
        $hasher = @{}
        foreach ($server in $Servers) {
            $hasher.Add($server, ([string]::Empty))
        }
        return $hasher
    }

    ########## Parameter Binding Exceptions ##############
    if ($EventID -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EventID. Needs to be a value greater than or equal to 1."
    }
    if ([string]::IsNullOrEmpty($LogName)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogName."
    }
    if ($null -eq $Servers -or
        $Servers.count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers."
    }
    if ($WriteUpdateMinuteInterval -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid WriteUpdateMinuteInterval. Needs to be a value greater than or equal to 1."
    }
    if ($SleepTime -lt 0) {
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
    $eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "SuspendMonitorServerHostWriters" -Value $SuspendMonitorServerHostWriters
    $eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "EventFilterStartTimeUpdateEnabled" -Value $EventFilterStartTimeUpdateEnabled
    $eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "EventFilterStartTimeUpdateIntervalInSeconds" -Value $EventFilterStartTimeUpdateIntervalInSeconds
    $eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateFilterStartTime" -Value ([DateTime]::MinValue)
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

    $filterHashTable = @{
        LogName   = $LogName
        ID        = $EventID
        StartTime = $StartTime
    }
    if ($Level -ne -1) {
        $filterHashTable.Add("Level", $Level)
    }
    if (!([string]::IsNullOrEmpty($ProviderName))) {
        $filterHashTable.Add("ProviderName", $ProviderName)
    }
    $eventLogMonitorObject | Add-Member -MemberType NoteProperty -Name "FilterHashtable" -Value $filterHashTable

    if ($null -ne $HostFunctionCaller) {
        $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
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
        if ([DateTime]::Now -gt $this.NextUpdateTime) {
            $this.WriteHostWriter(("[{0}] : Everything is passing checks thus far..." -f ([DateTime]$dt = [DateTime]::Now)))
            $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
        }
    }

    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "ResetStatus" -Value {
        foreach ($server in $this.Servers) {
            $this.ServerEventData[$server] = [string]::Empty
            $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::Passed
        }
        #going to also update the start time and Next update Time
        $this.UpdateStartTime()
        $this.NextUpdateTime = [DateTime]::Now
    }

    $eventLogMonitorObject | Add-Member -MemberType  ScriptMethod -Name "GetConditionServers" -Value {
        $conditionServer = @() ##Needs to be array in case they don't reset the data
        foreach ($server in $this.Servers) {
            if ($this.ServerStatus[$server] -eq [EventLogMonitor.StatusCode]::ConditionMet) {
                $conditionServer += $server
            }
        }
        return $conditionServer
    }

    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetEventData" -Value {
        Function Get-StringArrayFromObjectDetails {
            param(
                [array]$Properties,
                [object]$EventData
            )
            $data = @()
            foreach ($property in $Properties) {
                $data += "{0}: `t{1}" -f $property, ($EventData | Select-Object $property).$property
            }
            return $data
        }

        $conditionServer = $this.GetConditionServers()
        $stringData = @("--Event Results--")
        foreach ($server in $conditionServer) {
            $data = $this.ServerEventData[$server]
            $stringData += ("Server {0} Event Data" -f $server)
            $stringData += ""
            $stringData += Get-StringArrayFromObjectDetails -Properties @("MachineName", "ID", "ProviderName", "TaskDisplayName", "LogName", "TimeCreated", "Message") -EventData $data
            $stringData += "--End Server Event Data--"
        }
        return $stringData
    }

    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetRawEventData" -Value {
        $conditionServer = $this.GetConditionServers()
        $events = @()
        foreach ($server in $conditionServer) {
            $events += $this.ServerEventData[$server]
        }
        return $events
    }

    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "MonitorServers" -Value {
        $eventOccurred = $false
        foreach ($server in $this.Servers) {
            [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
            $newEvents = Get-WinEvent -ComputerName $server -FilterHashtable $this.FilterHashTable -ErrorAction SilentlyContinue
            $this.WriteVerboseWriter(("Took {0} seconds to attempt to get data from server {1}" -f $timer.Elapsed.TotalSeconds, $server))
            if ($null -eq $newEvents) {
                $this.WriteVerboseWriter(("Server {0} didn't have any events" -f $server))
                continue;
            } else {
                if (!$this.SuspendMonitorServerHostWriters) { $this.WriteHostWriter(("Server {0} had event that we are looking for" -f $server)) }
                if ([string]::IsNullOrEmpty($this.MessageFilter) -and [string]::IsNullOrEmpty($this.TaskDisplayNameFilter)) {
                    $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::ConditionMet
                    $this.ServerEventData[$server] = $newEvents
                    $eventOccurred = $true
                    break;
                } else {
                    if (!$this.SuspendMonitorServerHostWriters) { $this.WriteHostWriter(("Need to filter down the results some more...")) }
                    foreach ($event in $newEvents) {
                        $validEvent = $false
                        if (!([string]::IsNullOrEmpty($this.MessageFilter))) {
                            if ($event.Message.Contains($this.MessageFilter)) {
                                $validEvent = $true
                                $this.WriteVerboseWriter("Event met message filter")
                            } else {
                                $this.WriteVerboseWriter("Event didn't meet message filter")
                                continue;
                            }
                        }
                        if (!([string]::IsNullOrEmpty($this.TaskDisplayNameFilter))) {
                            if ($event.TaskDisplayName -eq ($this.TaskDisplayNameFilter)) {
                                $validEvent = $true
                                $this.WriteVerboseWriter("Event met task display name filter")
                            } else {
                                $this.WriteVerboseWriter("Event didn't meet display name filter")
                                continue;
                            }
                        }
                        if ($validEvent) {
                            $this.ServerStatus[$server] = [EventLogMonitor.StatusCode]::ConditionMet
                            $this.ServerEventData[$server] = $newEvents
                            $eventOccurred = $true
                            break;
                        }
                    }
                }
            }
        }

        if ($eventOccurred) {
            return [EventLogMonitor.StatusCode]::ConditionMet
        }
        $this.WriteUpdate()
        return [EventLogMonitor.StatusCode]::Passed
    }

    $eventLogMonitorObject | Add-Member -MemberType ScriptMethod -Name "MonitorLoop" -Value {
        param(
            [int]$DurationInMinutes = 0
        )

        if ($DurationInMinutes -lt 0) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DurationInMinutes value. Needs to be a value 0 or greater. If 0 is provided, this loop will not break."
        }

        $breakLoopTime = [DateTime]::MaxValue
        if ($DurationInMinutes -ne 0) {
            $breakLoopTime = ([datetime]::Now).AddMinutes($DurationInMinutes)
            $this.WriteVerboseWriter("Setting break loop time for {0}" -f $breakLoopTime)
        } else {
            $this.WriteVerboseWriter("No break loop time is set. Will continue to run till condition is met.")
        }
        while ([datetime]::Now -lt $breakLoopTime) {
            if ($this.MonitorServers() -eq [EventLogMonitor.StatusCode]::ConditionMet) {
                return [EventLogMonitor.StatusCode]::ConditionMet
            }
            if ($this.EventFilterStartTimeUpdateEnabled -and
                [datetime]::Now -gt $this.NextUpdateFilterStartTime) {
                $this.UpdateStartTime(5)
            }
            Start-Sleep $this.SleepTime
        }
        $this.WriteVerboseWriter("No conditions were met during this loop")
        return [EventLogMonitor.StatusCode]::Passed
    }
    return $eventLogMonitorObject
}