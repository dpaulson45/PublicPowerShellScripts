Function New-PerformanceLogmanObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Not sure why i am doing this at the moment, need to look into it')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '', Justification = 'Not sure why i am doing this at the moment, need to look into it')]
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
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>
    <#
    TODO:
    - Be able to do none circular mode
    - Include File Versioning info
    - SaveFileDirectory needs to be better logic for checking to see if the path is valid on remote machines
    #>
    ########## Parameter Binding Exceptions ##############

    if ([string]::IsNullOrEmpty($PerformanceLogmanName)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceLogmanName"
    }
    if ([string]::IsNullOrEmpty($LogFormat) -or
        ($LogFormat -ne "bincirc" -and
            $LogFormat -ne "bin")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat. Only accepted values are bincirc and bin."
    }
    if ($MaxSizeMB -lt 512) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSizeMB. Value must be greater than or equal to 512."
    }
    if ((!($SystemDataCollectorSet)) -and
        ($null -eq $PerformanceCounters -or
            $PerformanceCounters.Count -eq 0)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounters"
    }
    if ($SystemDataCollectorSet -and
        (!($PerformanceLogmanName.StartsWith("System\")))) {
        $PerformanceLogmanName = "System\{0}" -f $PerformanceLogmanNames
    }
    if ($SystemDataCollectorSet -and
        $PerformanceLogmanName.Contains(" ")) {
        $PerformanceLogmanName = '"{0}"' -f $PerformanceLogmanName
    }
    if ($SampleInterval -lt 1 -or
        $SampleInterval -gt 30) {
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
    if (!([string]::IsNullOrEmpty($FileVersioning)) -and
        ($FileVersioning -ne "mmddhhmm" -and
            $FileVersioning -ne "nnnnnn")) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileVersioning. Value must be mmddhhmm or nnnnnn"
    }
    if ($null -eq $Servers -or
        $Servers.Count -eq 0) {
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
        foreach ($server in $Servers) {
            $statusObj = New-Object PSCustomObject
            $statusObj | Add-Member -MemberType NoteProperty -Name "DebugResults" -Value ([string]::Empty)
            $statusObj | Add-Member -MemberType NoteProperty -Name "LogmanStatusCode" -Value ([PerformanceLogman.StatusCode]::None)
            $hasher.Add($server, $statusObj)
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

    if ($null -ne $HostFunctionCaller) {
        $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "ExecuteLogmanAction" -Value {
        param(
            [PerformanceLogman.Action]$Action = [PerformanceLogman.Action]::Unknown,
            [array]$Servers = $this.Servers
        )
        $this.WriteVerboseWriter("Calling ExecuteLogmanAction")
        $this.WriteVerboseWriter("Action: {0}" -f $Action)
        if ($Action -eq [PerformanceLogman.Action]::Unknown) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Action in ExecuteLogmanAction"
        }
        $logmanAction = [string]::Empty
        if ($Action -eq [PerformanceLogman.Action]::Start) {
            $logmanAction = "Start"
        } elseif ($Action -eq [PerformanceLogman.Action]::Stop) {
            $logmanAction = "Stop"
        } elseif ($Action -eq [PerformanceLogman.Action]::Delete) {
            $logmanAction = "Delete"
        }
        $logman = $this.PerformanceLogmanName
        $failureOccurred = $false
        $maxSize = $this.MaxFileSizeMB
        $updateCount = 0
        $startLoopCount = 0
        foreach ($server in $Servers) {
            do {
                $updateLoop = $false
                if ($null -ne $this.RemoteCredentials) {
                    $this.WriteVerboseWriter("Executing this in an Invoke-Command script block.")
                    $executeString = "logman $logmanAction $logman"
                    [array]$results = Invoke-Command -ComputerName $server -ScriptBlock { param($ex); Invoke-Expression $ex } -Credential $this.RemoteCredentials -ArgumentList $executeString
                } else {
                    [array]$results = logman $logmanAction $logman -s $server
                }
                $this.ServersStatus[$server].DebugResults = $results
                $this.WriteVerboseWriter("Results from logman:")
                $this.WriteVerboseWriter($results)
                if (($results[-1]).Trim() -eq "The command completed successfully.") {
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
                } elseif ($Action -eq [PerformanceLogman.Action]::Start -and
                    ($results[-1]).Trim() -eq "Unable to create the specified log file.") {
                    $this.WriteVerboseWriter("Failed to start logman likely due to the size of the file on this system. Current size {0} MB" -f $maxSize)
                    $updateLoop = $true
                    $updateCount++
                    $maxSize++
                    if ($null -ne $this.RemoteCredentials) {
                        $executeString = "logman update counter $logman -max $maxSize"
                        [array]$results = Invoke-Command -ComputerName $server -ScriptBlock { param($ex); Invoke-Expression $ex } -Credential $this.RemoteCredentials -ArgumentList $executeString
                    } else {
                        [array]$results = logman update counter $logman -s $server -max $maxSize
                    }
                    $this.ServersStatus[$server].DebugResults = $results
                    if (($results[-1]).Trim() -eq "The command completed successfully.") {
                        $this.WriteVerboseWriter("Successfully updated the max size on the logman to {0} MB" -f $maxSize)
                        $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
                    } else {
                        $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                        $failureOccurred = $true
                        $updateLoop = $false
                        $this.WriteVerboseWriter("Failed to update the logman's max size. Going to fail out of this loop.")
                    }
                } elseif ($Action -eq [PerformanceLogman.Action]::Start -and
                    ($results[-1]).Trim() -eq "Cannot create a file when that file already exists." -and
                    $startLoopCount -lt $this.MaxStartUpdateLoop) {
                    $this.WriteVerboseWriter("Failed to start logman because file already exists. Going to continue to restart this.")
                    $updateLoop = $true
                    $startLoopCount++
                } else {
                    $this.WriteVerboseWriter("Failed to do logman action on server: {0}" -f $server)
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                    $failureOccurred = $true
                }
            }while ($updateLoop -and $updateCount -lt $this.IncreaseMaxSizeTimes)
        }
        if ($failureOccurred) {
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

        if ($this.SystemDataCollectorSet) {
            $this.WriteVerboseWriter("Can't delete a system data collector set.")
            return [PerformanceLogman.StatusCode]::Success
        }
        $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Delete)
        return $status
    }

    $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "CreateLogman" -Value {

        if ($this.SystemDataCollectorSet) {
            $this.WriteVerboseWriter("Can't create a system data collector set.")
            return [PerformanceLogman.StatusCode]::Success
        }
        $servers = $this.Servers
        [string]$path = $this.SaveFileDirectory
        if (!($path.EndsWith("\"))) {
            $path = $path + "\"
        }
        $logman = $this.PerformanceLogmanName
        $fullFilePathStandard = $path + $logman + "_{0}_Circular" #TODO in case we aren't doing circular this needs to change
        $format = $this.LogFormat
        $interval = $this.SampleInterval
        $maxSize = $this.MaxFileSizeMB
        $counters = $this.PerformanceCounters
        $failureOccurred = $false
        foreach ($server in $servers) {
            $this.WriteVerboseWriter("Creating logman on server: {0}" -f $server)
            $outputLocation = $fullFilePathStandard -f $server
            $this.WriteVerboseWriter("Output log location: {0}" -f $outputLocation)
            do {
                $createLoop = $false
                if ($null -ne $this.RemoteCredentials) {
                    $this.WriteVerboseWriter("Doing remote credential execution")
                    $configLocation = "{0}{1}_Counters.config" -f $path, $logman
                    $executeString = "logman create counter -n $logman -cf $configLocation -s $server -f $format -max $maxSize -si $interval -o $outputLocation"
                    $this.WriteVerboseWriter("Execution String: {0}" -f $executeString)
                    $argumentList = New-Object PSCustomObject
                    $argumentList | Add-Member -MemberType NoteProperty -Name "LogmanCommand" -Value $executeString
                    $argumentList | Add-Member -MemberType NoteProperty -Name "Counters" -Value $counters
                    $argumentList | Add-Member -MemberType NoteProperty -Name "ConfigLocation" -Value $configLocation
                    [array]$results = Invoke-Command -ComputerName $server -ScriptBlock { param($passedObject); $passedObject.Counters > $passedObject.ConfigLocation ; Invoke-Expression $passedObject.LogmanCommand } -Credential $this.RemoteCredentials -ArgumentList $argumentList
                } else {
                    [array]$results = logman create counter -n $logman -c $counters -s $server -f $format -max $maxSize -si $interval -o $outputLocation
                }
                $this.WriteVerboseWriter("Results from logman:")
                $this.WriteVerboseWriter($results)
                $this.ServersStatus[$server].DebugResults = $results
                if (($results[-1]).Trim() -eq "The command completed successfully.") {
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Success
                } elseif (($results[-1]).Trim() -eq "Data Collector already exists.") {
                    $this.WriteVerboseWriter("Data Collector Already exists on server {0} re-creating it." -f $server)
                    $status = $this.ExecuteLogmanAction([PerformanceLogman.Action]::Delete, $server)
                    if ($status -eq [PerformanceLogman.StatusCode]::Success) {
                        $createLoop = $true
                    } else {
                        $this.WriteVerboseWriter("Failed to re-create the data collector set. Failing out the request.")
                        $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                        $failureOccurred = $true
                    }
                } else {
                    $this.WriteVerboseWriter("Failed to create the data collector set. Failing out the request.")
                    $this.ServersStatus[$server].LogmanStatusCode = [PerformanceLogman.StatusCode]::Failed
                    $failureOccurred = $true
                }
            }while ($createLoop)
        }
        if ($failureOccurred) {
            return [PerformanceLogman.StatusCode]::Failed
        }
        return [PerformanceLogman.StatusCode]::Success
    }

    $performanceLogmanObject | Add-Member -MemberType ScriptMethod -Name "GetFailedStatusServers" -Value {
        $servers = $this.Servers
        $failedServers = @()
        foreach ($server in $servers) {
            if ($this.ServersStatus[$server].LogmanStatusCode -eq [PerformanceLogman.StatusCode]::Failed) {
                $failedServers += $server
            }
        }

        return $failedServers
    }

    return $performanceLogmanObject
}