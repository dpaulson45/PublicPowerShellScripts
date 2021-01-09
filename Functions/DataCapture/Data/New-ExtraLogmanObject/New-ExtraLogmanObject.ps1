Function New-ExtraLogmanObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$LogmanName = "ExchangeLogman",
        [Parameter(Mandatory = $false)][string]$FileName,
        [Parameter(Mandatory = $false)][int]$EtlFileSize = 400,
        #[Parameter(Mandatory=$false)][string]$EtlCNF, # = "00:30:00", #TODO see if this is truly needed
        [Parameter(Mandatory = $false)][string]$FileDirectory = "C:\Traces",
        [Parameter(Mandatory = $false)][string]$Provider = "`{79bb49e6-2a2c-46e4-9167-fa122525d540`}",
        [Parameter(Mandatory = $false)][string]$AppendVersioningToFile = "mmddhhmm",
        [Parameter(Mandatory = $false)][array]$Servers,
        [Parameter(Mandatory = $false)][array]$ExtraTraceConfigFileContent
    )

    if ([string]::IsNullOrEmpty($LogmanName.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName"
    }
    if ($EtlFileSize -lt 100 -or $EtlFileSize -gt 1000) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 1000"
    }
    if ([string]::IsNullOrEmpty($FileDirectory.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileDirectory"
    }
    if ([string]::IsNullOrEmpty($Provider.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider"
    }
    if ([string]::IsNullOrEmpty($AppendVersioningToFile.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
    }
    if ($null -eq $Servers -or
        $Servers.Count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers"
    }
    if ($null -eq $ExtraTraceConfigFileContent -or
        $ExtraTraceConfigFileContent.Count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExtraTraceConfigFileContent"
    }
    if ([string]::IsNullOrEmpty($FileName.Trim())) {
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
        foreach ($server in $Servers) {
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

            $hasher.Add($server, $statusObject)
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
                [Parameter(Mandatory = $true)][string]$Line
            )
            $Line | Out-File -FilePath "C:\EnabledTraces.Config" -Encoding ascii -Append
        }

        $content = $this.ExtraTraceConfigFileContent
        New-Item -Path "C:\EnabledTraces.Config" -ItemType File -Force | Out-Null
        foreach ($line in $content) {
            Save-ExtraLine $line
        }

        $servers = $this.Servers
        foreach ($server in $servers) {
            if ($server -ne $Env:COMPUTERNAME) {
                try {
                    Copy-Item "C:\EnabledTraces.Config" "\\$server\C$\EnabledTraces.Config" -ErrorAction Stop
                    $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
                } catch {
                    $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Failed
                    $failureCount++
                }
            }
            #creating the file shouldn't be an issue locally
            else {
                $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
            }
        }

        if ($failureCount -ne 0) {
            return [ExtraLogman.StatusCode]::SingleServerFailure
        }
        return [ExtraLogman.StatusCode]::Success
    }

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {
        $servers = $this.Servers
        $logman = $this.TraceName
        $failureCount = 0
        foreach ($server in $servers) {
            [array]$results = logman start $logman -s $server
            $this.ServersStatus[$server].StartedResults = $results
            if (($results[-1]).Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Success
            } else {
                $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }
        switch ($failureCount) {
            0 { return [ExtraLogman.StatusCode]::Success }
            { ($failureCount -eq $servers.count) } { return [ExtraLogman.StatusCode]::AllFailure }
            default { return [ExtraLogman.StatusCode]::SingleServerFailure }
        }
    }

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
        $servers = $this.Servers
        $logman = $this.TraceName
        $failureCount = 0
        foreach ($server in $servers) {
            [array]$results = logman stop $logman -s $server
            $this.ServersStatus[$server].StoppedResults = $results
            if ($results[-1].Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Success
            } else {
                $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }

        switch ($failureCount) {
            0 { return [ExtraLogman.StatusCode]::Success }
            { ($failureCount -eq $servers.count) } { return [ExtraLogman.StatusCode]::AllFailure }
            default { return [ExtraLogman.StatusCode]::SingleServerFailure }
        }
    }

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "DeleteLogman" -Value {
        $servers = $this.Servers
        $logman = $this.TraceName
        $failureCount = 0
        foreach ($server in $servers) {
            [array]$results = logman delete $logman -s $server
            $this.ServersStatus[$server].DeletedResults = $results
            $this.ServersStatus[$server].LogmanStatus = ([string]::Empty)
            if ($results[-1].Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Success
            } else {
                $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }

        switch ($failureCount) {
            0 { return [ExtraLogman.StatusCode]::Success }
            { ($failureCount -eq $servers.count) } { return [ExtraLogman.StatusCode]::AllFailure }
            default { return [ExtraLogman.StatusCode]::SingleServerFailure }
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
        foreach ($server in $servers) {
            $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
            [array]$results = logman create trace $logman -max $maxSize -v $appendVersion -o $fullFileName -p $provider -s $server -bs 128 -f bincirc -mode globalsequence
            $this.ServersStatus[$server].CreatedResults = $results
            if ($results[-1].Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
            } elseif ($results[-1].Trim() -eq "Data Collector already exists.") {
                $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::DataCollectorExists
                $failureCount++ #for now count this as a failure.
            } else {
                $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }

        switch ($failureCount) {
            0 { return [ExtraLogman.StatusCode]::Success }
            { ($failureCount -eq $servers.count) } { return [ExtraLogman.StatusCode]::AllFailure }
            default { return [ExtraLogman.StatusCode]::SingleServerFailure }
        }
    }

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "CheckLogmanStatus" -Value {
        $servers = $this.Servers
        $logman = $this.TraceName
        foreach ($server in $servers) {
            [array]$results = logman $logman -s $server

            if ($results[-1].Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
                $i = 2
                if (-not ($results[$i].StartsWith("Status:"))) {
                    $i = 0
                    while ($i -lt $results.count) {
                        if (($results[$i].StartsWith("Status:"))) {
                            break
                        }
                        $i++
                    }
                }
                $lineStatus = $results[$i].Replace("Status:", "").Trim()
                $this.ServersStatus[$server].LogmanStatus = $lineStatus
                if ($lineStatus -eq "running") {
                    $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Running
                } elseif ($lineStatus -eq "stopped") {
                    $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Stopped
                }
            } else {
                $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::NotFound
                $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::None
            }
        }
        #For now, this should always return success
        return ([ExtraLogman.StatusCode]::Success)
    }

    return $logmanObject
}