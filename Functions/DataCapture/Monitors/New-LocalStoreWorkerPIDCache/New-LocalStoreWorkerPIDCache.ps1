#New-LocalStoreWorkerPIDCache
Function New-LocalStoreWorkerPIDCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWMICmdlet', '', Justification = 'Not sure why i am using this here over Get-Process.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][array]$MonitorDBsGUID,
        [Parameter(Mandatory = $false)][array]$MonitorDBsName,
        [Parameter(Mandatory = $false)][int]$UpdateCacheInterval = 300,
        [Parameter(Mandatory = $false)][bool]$WriteVerboseData = $true,
        [Parameter(Mandatory = $false)][scriptblock]$HostFunctionCaller,
        [Parameter(Mandatory = $false)][scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>

    ########## Parameter Binding Exceptions ##############

    if (($null -eq $MonitorDBsGUID -or
            $MonitorDBsGUID.Count -eq 0) -and
        ($null -eq $MonitorDBsName -or
            $MonitorDBsName.Count -eq 0)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide either a valid monitor MonitorDBsGUID or MonitorDBsName"
    }
    if ($null -eq $UpdateCacheInterval -or
        ($UpdateCacheInterval -lt 60 -or
            $UpdateCacheInterval -gt 3600)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide either a valid UpdateCacheInterval. Must be a value between 60 and 3600"
    }

    if ($null -ne $MonitorDBsGUID -and
        $MonitorDBsGUID.Count -gt 0) {
        $MonitorByGUIDs = $true
    }
    if ($null -ne $MonitorDBsName -and
        $MonitorDBsName -gt 0) {
        $MonitorByNames = $true
    }

    Function Save-MonitorByGUIDs {
        $upperGUID = @()
        foreach ($guid in $MonitorDBsGUID) {
            $upperGUID += $guid.ToUpper()
        }
        return $upperGUID
    }

    $localStoreWorkerPIDCache = New-Object PSCustomObject
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "MonitorByNames" -Value $MonitorByNames
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "MonitorByGUIDs" -Value $MonitorByGUIDs
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "MonitorDBsGUID" -Value (Save-MonitorByGUIDs)
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "MonitorDBsName" -Value $MonitorDBsName
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "UpdateCacheInterval" -Value $UpdateCacheInterval
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([System.DateTime]::Now)
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "PIDCacheGUID" -Value (@{})
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "PIDCacheNames" -Value (@{})
    $localStoreWorkerPIDCache | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $WriteVerboseData
    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}

    if ($null -ne $HostFunctionCaller) {
        $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }

    if ($null -ne $VerboseFunctionCaller) {
        $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }


    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdateCacheTime" -Value {
        $this.NextUpdateTime = ([System.DateTime]::Now).AddSeconds($this.UpdateCacheInterval)
    }

    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdatePIDCache" -Value {

        $this.WriteVerboseWriter("Calling Update PID Cache")
        if ($this.MonitorByGUIDs) {
            $this.WriteVerboseWriter("Monitor by GUIDs is enabled updating the PID via Process ID command line")
            $this.PIDCacheGUID = @{}
            $allStoreWorkers = Get-WmiObject Win32_Process -Filter "Name = 'Microsoft.Exchange.Store.Worker.exe'"
            foreach ($worker in $allStoreWorkers) {
                $commandLine = $worker.CommandLine
                if ($null -ne $commandLine) {
                    $dbGUID = ($commandLine.Substring(($start = $commandLine.IndexOf("-id:") + 4), $commandLine.IndexOf(" ", $start) - $start)).ToUpper()
                    if ($this.MonitorDBsGUID.Contains($dbGUID)) {
                        $workerPID = $worker.ProcessId
                        $this.WriteVerboseWriter("Adding GUID: {0}" -f $dbGUID)
                        $this.WriteVerboseWriter("Value PID: {0}" -f $workerPID)
                        $this.PIDCacheGUID.Add($dbGUID, $workerPID)
                    } else {
                        $this.WriteVerboseWriter("Failed to find GUID '{0}' in the list to monitor" -f $dbGUID)
                    }
                } else {
                    $this.WriteVerboseWriter("Command Line is null. Failed to determine what PID '{0}' belongs to" -f $worker.ProcessId)
                }
            }
        }
        if ($this.MonitorByNames) {
            $this.PIDCacheNames = @{}
            foreach ($db in $this.MonitorDBsName) {
                $counter = "\MSExchangeIS store({0})\Process ID" -f $db
                $workerPID = (Get-Counter -Counter $counter).CounterSamples.CookedValue
                $this.PIDCacheNames.Add($db, $workerPID)
            }
        }

        $this.UpdateCacheTime()
    }

    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdatePIDCacheIfNeeded" -Value {
        if ([System.DateTime]::Now -gt $this.NextUpdateTime) {
            $this.UpdatePIDCache()
        }
    }

    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "GetPIDNow" -Value {
        param(
            [string]$DBLookup
        )

        if ([string]::IsNullOrWhiteSpace($DBLookup)) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide DBLookup"
        }

        #GUID length
        if ($DBLookup.Length -eq 36) {
            return $this.PIDCacheGUID[$DBLookup]
        } else {
            return $this.PIDCacheNames[$DBLookup]
        }
    }

    $localStoreWorkerPIDCache.UpdatePIDCache()

    return $localStoreWorkerPIDCache
}