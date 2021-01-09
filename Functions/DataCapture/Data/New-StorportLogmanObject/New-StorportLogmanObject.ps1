Function New-StorportLogmanObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '', Justification = 'Not sure why i am doing this at the moment, need to look into it')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$LogmanName = "storport",
        [Parameter(Mandatory = $false)][string]$SaveName,
        [Parameter(Mandatory = $false)][int]$EtlFileSize = 4096,
        [Parameter(Mandatory = $false)][string]$SavePath = "C:\Traces",
        [Parameter(Mandatory = $false)][string]$Provider = "Microsoft-Windows-StorPort",
        [Parameter(Mandatory = $false)][string]$AppendVersioningToFile = "mmddhhmm",
        [Parameter(Mandatory = $false)][array]$ServerList,
        [Parameter(Mandatory = $false)][string]$KeywordsAny = "0xffffffffffffffff",
        [Parameter(Mandatory = $false)][string]$Level = "0xff",
        [Parameter(Mandatory = $false)][int]$MinimumBuffer = 16, #Note this appears to have a max min value of 20 on newer systems but still works
        [Parameter(Mandatory = $false)][int]$MaximumBuffer = 16,
        [Parameter(Mandatory = $false)][int]$BufferSizeKB = 1024, #default is actually 8KB
        [Parameter(Mandatory = $false)][string]$LogFormat = "bincirc"
    )

    #Following this blog: https://blogs.technet.microsoft.com/askcore/2013/04/25/tracing-with-storport-in-windows-2012-and-windows-8-with-kb2819476-hotfix/
    if ([string]::IsNullOrEmpty($LogmanName.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName"
    }
    if ($EtlFileSize -lt 100 -or
        $EtlFileSize -gt 10000) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 10000"
    }
    if ([string]::IsNullOrEmpty($SavePath.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SavePath"
    }
    if ([string]::IsNullOrEmpty($Provider.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider"
    }
    if ([string]::IsNullOrEmpty($AppendVersioningToFile.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
    }
    if ($ServerList -eq $null -or
        $ServerList.Count -eq 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ServerList"
    }
    if ([string]::IsNullOrEmpty($KeywordsAny.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid KeywordsAny"
    }
    if ([string]::IsNullOrEmpty($Level.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Level"
    }
    if ($MinimumBuffer -lt 10 -or
        $MinimumBuffer -gt 1000) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MinimumBuffer. Use a value between 10 and 1000"
    }
    if ($MaximumBuffer -lt 10 -or
        $MaximumBuffer -gt 1000) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaximumBuffer. Use a value between 10 and 1000"
    }
    if ($BufferSizeKB -lt 8 -or
        $BufferSizeKB -gt 4096) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BufferSizeKB. Use a value between 8 and 4096"
    }
    if ([string]::IsNullOrEmpty($LogFormat.Trim())) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat"
    }
    if ([string]::IsNullOrEmpty($SaveName.Trim())) {
        $SaveName = $LogmanName
    }

    Add-Type -TypeDefinition @"
    namespace StorportLogman
    {
        public enum StatusCode
        {
            None,
            Success,
            SingleServerFailure,
            Failed
        }
    }
"@

    Function New-ServersStatusObject {

        $hasher = @{}
        foreach ($server in $ServerList) {
            $statusObject = New-Object PSCustomObject
            $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartResults" -Value ([string]::Empty)
            $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartStatusCode" -Value ([StorportLogman.StatusCode]::None)
            $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedResults" -Value ([string]::Empty)
            $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedStatusCode" -Value ([StorportLogman.StatusCode]::None)

            $hasher.Add($server, $statusObject)
        }
        return $hasher
    }

    $logmanObject = New-Object PSCustomObject

    $logmanObject | Add-Member -MemberType NoteProperty -Name "TraceName" -Value $LogmanName
    $logmanObject | Add-Member -MemberType NoteProperty -Name "ETLFileSize" -Value $EtlFileSize
    $logmanObject | Add-Member -MemberType NoteProperty -Name "Provider" -Value $Provider
    $logmanObject | Add-Member -MemberType NoteProperty -Name "AppendVersion" -Value $AppendVersioningToFile
    $logmanObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $SavePath
    $logmanObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $SaveName
    $logmanObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $ServerList
    $logmanObject | Add-Member -MemberType NoteProperty -Name "ServersStatus" -Value (New-ServersStatusObject)
    $logmanObject | Add-Member -MemberType NoteProperty -Name "KeywordsAny" -Value $KeywordsAny
    $logmanObject | Add-Member -MemberType NoteProperty -Name "Level" -Value $Level
    $logmanObject | Add-Member -MemberType NoteProperty -Name "MinimumBuffer" -Value $MinimumBuffer
    $logmanObject | Add-Member -MemberType NoteProperty -Name "MaximumBuffer" -Value $MaximumBuffer
    $logmanObject | Add-Member -MemberType NoteProperty -Name "BufferSizeKB" -Value $BufferSizeKB
    $logmanObject | Add-Member -MemberType NoteProperty -Name "LogFormat" -Value $LogFormat

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "CreateAndStartTrace" -Value {

        $servers = $this.Servers
        $path = $this.FileDirectory
        $fileName = $this.FileName
        $maxSize = $this.EtlFileSize
        $logman = $this.TraceName
        #$appendVersion = $this.AppendVersion: TODO Fix
        $provider = $this.Provider
        $keywordsAny = $this.KeywordsAny
        $level = $this.Level
        $minimumBuffer = $this.MinimumBuffer
        $maximumBuffer = $this.MaximumBuffer
        $bufferSizeKB = $this.BufferSizeKB
        $logFormat = $this.LogFormat
        $failedCount = 0
        foreach ($server in $servers) {
            $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
            [array]$results = logman create trace $logman -o $fullFileName -p $provider $keywordsAny $level -nb $minimumBuffer $maximumBuffer -bs $bufferSizeKB -f $logFormat -max $maxSize -s $server -ets
            $this.ServersStatus[$server].CreateStartResults = $results
            if ($results[-1].Trim() -eq "The command completed successfully.") {
                $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Success
            } else {
                $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Failed
                $failedCount++
            }
        }
        switch ($failedCount) {
            0 { return [StorportLogman.StatusCode]::Success }
            { (-eq $servers.Count) } { return [StorportLogman.StatusCode]::Failed }
            default { return [StorportLogman.StatusCode]::SingleServerFailure }
        }
    }

    $logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {

        $servers = $this.Servers
        $logman = $this.TraceName
        $failureCount = 0
        foreach ($server in $servers) {
            [array]$results = logman stop $logman -s $server -ets
            $this.ServersStatus[$server].StoppedResults = $results
            if (($results[-1].Trim()) -eq "The command completed successfully.") {
                $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Success
            } else {
                $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Failed
                $failureCount++
            }
        }

        switch ($failureCount) {
            0 { return [StorportLogman.StatusCode]::Success }
            { ($failureCount -eq $servers.Count) } { return [StorportLogman.StatusCode]::Failed }
            default { return [StorportLogman.StatusCode]::SingleServerFailure }
        }
    }

    return $logmanObject
}