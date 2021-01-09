Function New-TraceLogmanObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Determine why i am using this')]
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
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>
    <#
    TODO:
        - Handle EventTraceSessionsEnabled being enabled with FileVersioning
        - Include FileVersioning
        - SaveFileDirectory needs to have smart logic for remote servers not having a valid path
        - Fix logic when we have EventTraceSessionsEnabled, on delete we don't check to see if the same name of trace is running/created that didn't use EventTraceSessions prior.
    #>

    ########## Parameter Binding Exceptions ##############

    if ([string]::IsNullOrEmpty($TraceLogmanName.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid TraceLogmanName"
    }
    if ([string]::IsNullOrEmpty($LogFormat) -or
        ($LogFormat -ne "bincirc" -and
            $LogFormat -ne "bin")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat. Only accepted values are bincirc and bin."
    }
    if ($MaxSizeMB -lt 100) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSizeMB. Value must be greater than or equal to 100."
    }
    if ([string]::IsNullOrEmpty($SaveFileDirectory)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveFileDirectory"
    }
    if (!([string]::IsNullOrEmpty($FileVersioning)) -and
        ($FileVersioning -ne "mmddhhmm" -and
            $FileVersioning -ne "nnnnnn")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileVersioning. Value must be mmddhhmm or nnnnnn"
    }
    if ($null -eq $Servers -or
        $Servers.Count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers"
    }
    if ($null -eq $NumberBuffers -or
        $NumberBuffers.Count -ne 2 -or
        $NumberBuffers[0].GetType().Name -ne "Int32" -or
        $NumberBuffers[1].GetType().Name -ne "Int32" -or
        $NumberBuffers[0] -lt 16 -or
        $NumberBuffers[1] -lt 16) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid NumberBuffers. Must be an array with to int32 values that are equal or greater than 16."
    }
    if ($BufferSize -lt 16) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BufferSize. Value must be greater than or equal to 16."
    }
    if ([string]::IsNullOrEmpty($Mode) -or
        ($Mode -ne "globalsequence" -and
            $Mode -ne "localsequence" -and
            $Mode -ne "pagedmemory")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Mode. Accepted values are globalsequence, localsequence, and pagedmemory."
    }
    if ([string]::IsNullOrEmpty($Provider)) {
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
        foreach ($server in $Servers) {
            $statusObj = New-Object PSCustomObject
            $statusObj | Add-Member -MemberType NoteProperty -Name "DebugResults" -Value ([string]::Empty)
            $statusObj | Add-Member -MemberType NoteProperty -Name "LogmanStatusCode" -Value ([TraceLogman.StatusCode]::None)
            $hasher.Add($server, $statusObj)
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

    if ($null -ne $HostFunctionCaller) {
        $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "ExecuteLogmanAction" -Value {
        param(
            [TraceLogman.Action]$Action = [TraceLogman.Action]::Unknown,
            [array]$Servers = $this.Servers
        )
        $this.WriteVerboseWriter("Calling ExecuteLogmanAction")
        $this.WriteVerboseWriter("Action: {0}" -f $Action)
        if ($Action -eq [TraceLogman.Action]::Unknown) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Action in ExecuteLogmanAction"
        }
        $logmanAction = [string]::Empty
        if ($Action -eq [TraceLogman.Action]::Start) {
            $logmanAction = "Start"
        } elseif ($Action -eq [TraceLogman.Action]::Stop) {
            $logmanAction = "Stop"
        } elseif ($Action -eq [TraceLogman.Action]::Delete) {
            $logmanAction = "Delete"
        }
        $logman = $this.TraceLogmanName
        $failureOccurred = $false
        $ets = ""
        if ($this.EventTraceSessionsEnabled) {
            $ets = "-ets"
        }
        foreach ($server in $Servers) {
            $this.WriteVerboseWriter("Runing logman against server: {0}" -f $server)
            [array]$results = logman $logmanAction $logman -s $server $ets
            $this.ServersStatus[$server].DebugResults = $results
            $this.WriteVerboseWriter("Results from logman:")
            $this.WriteVerboseWriter($results)
            if (($results[-1]).Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Success
            } else {
                $this.WriteVerboseWriter("Failed to do logman action on server: {0}" -f $server)
                $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
                $failureOccurred = $true
            }
        }
        if ($failureOccurred) {
            return [TraceLogman.StatusCode]::Failed
        }

        return [TraceLogman.StatusCode]::Success
    }

    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {
        if ($this.EventTraceSessionsEnabled) {
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
        if ($this.EventTraceSessionsEnabled) {
            $this.WriteVerboseWriter("Can't stop the logman trace when Event Trace Sessions is enabled. On Stop the data collector set is already removed. Going to return Success.")
            return [TraceLogman.StatusCode]::Success
        }
        $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Delete)
        return $status
    }

    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "CreateLogman" -Value {
        $servers = $this.Servers
        [string]$path = $this.SaveFileDirectory
        if (!($path.EndsWith("\"))) {
            $path = $path + "\"
        }
        $logman = $this.TraceLogmanName
        $fullFilePathStandard = $path + $logman + "_{0}.etl"
        $format = $this.LogFormat
        $maxSize = $this.MaxSizeMB
        $provider = $this.Provider
        #$fileVersioning = $this.FileVersioning: TODO Fix
        $numBuffer1 = $this.NumberBuffers[0]
        $numBuffer2 = $this.NumberBuffers[1]
        $bufferSize = $this.BufferSize
        $mode = $this.Mode
        $ets = ""
        if ($this.EventTraceSessionsEnabled) {
            $ets = "-ets"
        }
        $overWrite = ""
        if ($this.OverwriteExistingFile) {
            $overWrite = "-ow"
        }
        $failureOccurred = $false
        foreach ($server in $servers) {
            $this.WriteVerboseWriter("Creating logman on server: {0}" -f $server)
            $outputLocation = $fullFilePathStandard -f $server
            $this.WriteVerboseWriter("Output log location: {0}" -f $outputLocation)

            do {
                $createLoop = $false
                $executeCommand = "logman create trace -n $logman -s $server $overWrite -o $outputLocation -p $provider -nb $numBuffer1 $numBuffer2 -bs $bufferSize -mode $mode -f $format -max $maxSize $ets"
                $this.WriteVerboseWriter("Full Command String: {0}" -f $executeCommand)
                [array]$results = Invoke-Expression $executeCommand #if we don't use Invoke-Expression here for some reason we get: Error: Element not found.; Failed to create the data collector set. Failing out the request.
                $this.WriteVerboseWriter("Results from logman:")
                $this.WriteVerboseWriter($results)
                $this.ServersStatus[$server].DebugResults = $results
                if (($results[-1]).Trim() -eq "The command completed successfully.") {
                    $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Success
                } elseif (($results[-1]).Trim() -eq "Data Collector Set already exists.") {
                    $this.WriteVerboseWriter("Data Collector Already exists on server {0} re-creating it." -f $server)
                    $status = $this.ExecuteLogmanAction([TraceLogman.Action]::Delete, $server)
                    if ($status -eq [TraceLogman.StatusCode]::Success) {
                        $createLoop = $true
                    } else {
                        $this.WriteVerboseWriter("Failed to re-create the data collector set. Failing out the request.")
                        $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
                        $failureOccurred = $true
                    }
                } else {
                    $this.WriteVerboseWriter("Failed to create the data collector set. Failing out the request.")
                    $this.ServersStatus[$server].LogmanStatusCode = [TraceLogman.StatusCode]::Failed
                    $failureOccurred = $true
                }
            }while ($createLoop)
        }
        if ($failureOccurred) {
            return [TraceLogman.StatusCode]::Failed
        }
        return [TraceLogman.StatusCode]::Success
    }

    $traceLogmanObject | Add-Member -MemberType ScriptMethod -Name "GetFailedStatusServers" -Value {
        $servers = $this.Servers
        $failedServers = @()
        foreach ($server in $servers) {
            if ($this.ServersStatus[$server].LogmanStatusCode -eq [TraceLogman.StatusCode]::Failed) {
                $failedServers += $server
            }
        }
        return $failedServers
    }

    return $traceLogmanObject
}