Function New-NetshTraceObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'They are being used')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$ServerList,
        [Parameter(Mandatory = $false)][string]$Scenario = "netconnection",
        [Parameter(Mandatory = $false)][string]$CustomProviderString, #Custom provider string needs to be done like this, otherwise PowerShell fails to find the provider: provider='{EB004A05-9B1A-11D4-9123-0050047759BC}' keywords=0x3fffffff level=0x7
        [Parameter(Mandatory = $false)][string]$Persistent = "Yes",
        [Parameter(Mandatory = $false)][string]$BaseFileName = "NetworkCapture",
        [Parameter(Mandatory = $false)][string]$SaveDirectory = "C:\",
        [Parameter(Mandatory = $false)][int]$MaxSize = 2048,
        [Parameter(Mandatory = $false)][string]$Capture = "Yes",
        [Parameter(Mandatory = $false)][string]$Report = "Yes",
        [Parameter(Mandatory = $false)][string]$Correlation = "No",
        [Parameter(Mandatory = $false)][string]$FileMode = "circular",
        [Parameter(Mandatory = $false)][string]$Overwrite = "Yes",
        [Parameter(Mandatory = $false)][bool]$WriteVerboseData = $false,
        [Parameter(Mandatory = $false)][scriptblock]$HostFunctionCaller,
        [Parameter(Mandatory = $false)][scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>
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

    ##############################
    #
    #    Script Functions
    #
    ##############################
    Function New-ServerStatusHashtable {
        $hasher = @{}
        foreach ($server in $ServerList) {
            $hasher.Add($server, ([NetshTraceObject.StatusCode]::None))
        }
        return $hasher
    }

    Function New-ServerStatusDetailsHashtables {
        $hasher = @{}
        foreach ($server in $ServerList) {
            $hasher.Add($server, "None")
        }
        return $hasher
    }

    ########## Parameter Binding Exceptions ##############

    $usingCustomProviderString = $false
    if (!([string]::IsNullOrEmpty($CustomProviderString))) {
        $usingCustomProviderString = $true
    }
    if ([string]::IsNullOrEmpty($Scenario) -and
        (!($usingCustomProviderString))) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Scenario"
    }
    if ($Persistent -ne "Yes" -and
        $Persistent -ne "No") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Persistent. Needs to be 'Yes' or 'no'"
    }
    if ([string]::IsNullOrEmpty($BaseFileName)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BaseFileName"
    }
    if ([string]::IsNullOrEmpty($SaveDirectory)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveDirectory"
    }
    if ($MaxSize -lt 0 -or
        $MaxSize -gt (10 * 1MB)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSize. Provide a value between 0 and 10240 MB"
    }
    if ($Capture -ne "Yes" -and
        $Capture -ne "No") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Capture. Needs to be 'Yes' or 'No'"
    }
    if ($Report -ne "Yes" -and
        $Report -ne "No" -and
        $Report -ne "Disabled") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Report. Needs to be 'Yes' or 'No' or 'Disabled'"
    }
    if ($Correlation -ne "Yes" -and
        $Correlation -ne "No" -and
        $Correlation -ne "Disabled") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Correlation. Needs to be 'Yes' or 'No' or 'Disabled'"
    }
    if ($FileMode -ne "Single" -and
        $FileMode -ne "Circular" -and
        $FileMode -ne "append") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileMode. Needs to be 'Single' or 'Circular' or 'Append'"
    }
    if ($Overwrite -ne "Yes" -and
        $Overwrite -ne "No") {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Overwrite. Needs to be 'Yes' or 'No'"
    }

    $netshTraceObj = New-Object PSCustomObject
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
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}


    if ($null -ne $HostFunctionCaller) {
        $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }


    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartJobManager" -Value {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)][array]$ServersWithArguments,
            [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
            [Parameter(Mandatory = $false)][string]$JobBatchName,
            [Parameter(Mandatory = $false)][bool]$DisplayReceiveJob = $false,
            [Parameter(Mandatory = $false)][bool]$DisplayReceiveJobInVerboseFunction,
            [Parameter(Mandatory = $false)][bool]$DisplayReceiveJobInCorrectFunction,
            [Parameter(Mandatory = $false)][bool]$NeedReturnData = $true
        )

        Function Write-ReceiveJobData {
            param(
                [Parameter(Mandatory = $true)][array]$ReceiveJobData
            )
            $returnJob = [string]::Empty
            foreach ($job in $ReceiveJobData) {
                if ($job["Verbose"]) {
                    $this.WriteVerboseWriter($job["Verbose"])
                } elseif ($job["Host"]) {
                    $this.WriteHostWriter($job["Host"])
                } elseif ($job["ReturnObject"]) {
                    $returnJob = $job["ReturnObject"]
                } else {
                    $this.WriteVerboseWriter("Unable to determine the key for the return type.")
                }
            }
            return $returnJob
        }

        Function Start-Jobs {
            $this.WriteVerboseWriter("Calling Start-Jobs")
            foreach ($serverObject in $ServersWithArguments) {
                $server = $serverObject.ServerName
                $argumentList = $serverObject.ArgumentList
                $this.WriteVerboseWriter(("Starting job on server {0}" -f $server))
                Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock -ArgumentList $argumentList -AsJob -JobName $server | Out-Null
            }
        }

        Function Confirm-JobsPending {
            $jobs = Get-Job
            if ($null -ne $jobs) {
                return $true
            }
            return $false
        }

        Function Wait-JobsCompleted {
            [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
            $returnData = @{}
            while (Confirm-JobsPending) {
                $completedJobs = Get-Job | Where-Object { $_.State -ne "Running" }
                if ($null -eq $completedJobs) {
                    Start-Sleep 1
                    continue
                }

                foreach ($job in $completedJobs) {
                    $receiveJobNull = $false
                    $jobName = $job.Name
                    $receiveJob = Receive-Job $job
                    Remove-Job $job
                    if ($null -eq $receiveJob) {
                        $receiveJobNull = $True
                        $this.WriteHostWriter(("Job {0} didn't have any receive job data" -f $jobName))
                    }
                    if ($DisplayReceiveJobInVerboseFunction -and
                        (-not($receiveJobNull))) {
                        $this.WriteHostWriter(("[JobName: {0}] : {1}" -f $jobName, $receiveJob))
                    } elseif ($DisplayReceiveJobInCorrectFunction -and
                        (-not ($receiveJobNull))) {
                        $returnJobData = Write-ReceiveJobData -ReceiveJobData $receiveJob
                        if ($null -ne $returnJobData) {
                            $returnData.Add($jobName, $returnJobData)
                        }
                    } elseif ($DisplayReceiveJob -and
                        (-not($receiveJobNull))) {
                        $this.WriteHostWriter($receiveJob)
                    }
                    if ($NeedReturnData -and
                        (-not($DisplayReceiveJobInCorrectFunction))) {
                        $returnData.Add($job.Name, $receiveJob)
                    }
                }
            }
            $timer.Stop()
            $this.WriteVerboseWriter(("Waiting for jobs to complete took {0} seconds" -f $timer.Elapsed.TotalSeconds))
            if ($NeedReturnData) {
                return $returnData
            }
            return $null
        }

        [System.Diagnostics.Stopwatch]$timerMain = [System.Diagnostics.Stopwatch]::StartNew()

        Start-Jobs
        $data = Wait-JobsCompleted
        $timerMain.Stop()
        $this.WriteVerboseWriter(("Exiting: Start-JobManager | Time in Start-JobManager: {0} seconds" -f $timerMain.Elapsed.TotalSeconds))
        if ($NeedReturnData) {
            return $data
        }
        return $null
    }


    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StopTrace" -Value {

        $serversWithArguments = @()
        foreach ($server in $this.ServerList) {
            $obj = New-Object PSCustomObject
            $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
            $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
            $serversWithArguments += $obj
        }
        $this.WriteHostWriter(("[{0}] : Attempting to stop the netsh trace. This may take some time to complete." -f ([datetime]::Now)))
        $scriptBlock = [scriptblock]::Create("netsh trace stop")
        $results = $this.StartJobManager($serversWithArguments, $scriptBlock)
        $allPassed = $true
        foreach ($server in $this.ServerList) {
            $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to stop the trace" -f $server))
            $data = $results[$server]
            $this.ServerStatusDetails[$server] = $data
            $serverSuccess = $false
            $index = 0
            if ($data[0].Trim() -eq "There is no trace session currently in progress.") {
                $serverSuccess = $true
            } elseif ($data[3].Trim() -eq "Tracing session was successfully stopped.") {
                $serverSuccess = $true
            } else {
                while ($index -lt $data.Count) {
                    if ($data[$index].Trim() -eq "Tracing session was successfully stopped.") {
                        $serverSuccess = $true
                        break;
                    }
                    $index++
                }
            }
            if ($serverSuccess) {
                $this.WriteVerboseWriter(("Server {0} appears to have stopped the trace" -f $server))
                $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success
            } else {
                $this.WriteVerboseWriter(("Server {0} appears to have failed to stop the trace" -f $server))
                $this.WriteVerboseWriter($data)
                $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
                $allPassed = $false
            }
        }

        if ($allPassed) {
            return [NetshTraceObject.StatusCode]::Success
        }

        return [NetshTraceObject.StatusCode]::Failed
    }

    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartTrace" -Value {
        $serversWithArguments = @()
        foreach ($server in $this.ServerList) {
            $obj = New-Object PSCustomObject
            $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
            $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
            $serversWithArguments += $obj
        }

        $this.TraceFile = "{0}\{1}_{2}.etl" -f $this.SaveDirectory, $this.BaseFileName, ((Get-Date).ToString("yyyyMMddHHmmss"))
        $scriptBlockString = "Netsh trace start capture={0} maxsize={1} persistent={2} tracefile={3} correlation={4} overwrite={5} report={6}" -f $this.Capture,
        $this.MaxSize, $this.Persistent, $this.TraceFile, $this.Correlation, $this.Overwrite, $this.Report
        if ($this.UsingCustomProvider) {
            $scriptBlockString = "{0} {1}" -f $scriptBlockString, $this.CustomProviderString
        } else {
            $scriptBlockString = "{0} scenario={1}" -f $scriptBlockString, $this.Scenario
        }
        $this.WriteVerboseWriter(("Full netsh command: '{0}'" -f $scriptBlockString))
        $scriptBlock = [ScriptBlock]::Create($scriptBlockString)

        $results = $this.StartJobManager($serversWithArguments, $scriptBlock)
        $allPassed = $true
        foreach ($server in $this.ServerList) {
            $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to start the trace" -f $server))
            $data = $results[$server]
            $this.ServerStatusDetails[$server] = $data
            $index = 0
            if ($data.count -lt 3) {
                #We either failed or have a netsh trace start need to fail them both out
                $index = -1
            } elseif ($data[3].StartsWith("Status")) {
                $index = 3
            } else {
                while ($index -lt $data.count) {
                    if ($data[$index].StartsWith("Status")) {
                        break;
                    }
                    $index++
                }
                if ($index -eq $data.count) {
                    $index = -1
                }
            }
            if ($index -eq -1 -or
                (-not($data[$index].Contains("Running")))) {
                $this.WriteHostWriter(("Server {0} appears to have failed to start the trace" -f $server))
                $this.WriteHostWriter($data)
                $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
                $allPassed = $false
            } else {
                $this.WriteVerboseWriter(("Server {0} appears to have started the trace" -f $server))
                $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success
            }
        }
        if ($allPassed) {
            return [NetshTraceObject.StatusCode]::Success
        } else {
            return [NetshTraceObject.StatusCode]::Failed
        }
    }

    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "GetFailedServerStatusDetails" -Value {

        $stringReturnObject = @()
        foreach ($server in $this.ServerList) {
            if ($this.ServerStatus[$server] -eq [NetshTraceObject.StatusCode]::Failed) {
                $this.WriteVerboseWriter(("Serer {0} appears to have failed. Collecting the information" -f $server))
                $data = $this.ServerStatusDetails[$server]
                $stringReturnObject += "Server Failed Data: {0}" -f $server
                $stringReturnObject += $data
                $stringReturnObject += "--End--"
                $stringReturnObject += ""
            } else {
                $this.WriteVerboseWriter(("Server {0} appears to not have failed." -f $server))
            }
        }
        return $stringReturnObject
    }

    return $netshTraceObj
}