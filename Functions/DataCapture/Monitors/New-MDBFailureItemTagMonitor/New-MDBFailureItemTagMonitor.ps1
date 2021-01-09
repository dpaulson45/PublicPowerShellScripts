Function New-MDBFailureItemTagMonitor {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][array]$TagIDs = @(38, 39),
        [Parameter(Mandatory = $false)][array]$DatabaseGUIDsToMonitor,
        [Parameter(Mandatory = $false)][bool]$VerboseEnabled,
        [Parameter(Mandatory = $false)][object]$LoggerObject,
        [Parameter(Mandatory = $false)][scriptblock]$HostFunctionCaller,
        [Parameter(Mandatory = $false)][scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/DataCapture/Monitors/New-EventLogMonitorObject/New-EventLogMonitorObject.ps1
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

    if ($TagIDs -eq $null -and $TagIDs.Count -gt 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid TagIDs."
    }
    if ($DatabaseGUIDsToMonitor -ne $null -and $DatabaseGUIDsToMonitor.Count -gt 0) {
        $FilterByDBGuidEnabled = $true
        $DatabaseGUIDsToMonitor = $DatabaseGUIDsToMonitor.ToUpper()
    } else {
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

    if ($HostFunctionCaller -ne $null) {
        $failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($VerboseFunctionCaller -ne $null) {
        $failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    $failureItemTagMonitor | Add-Member -MemberType ScriptMethod -Name "MonitorEvents" -Value {

        $monitorStatus = $this.MonitorEventObject.MonitorServers()
        if ($monitorStatus -eq [EventLogMonitor.StatusCode]::ConditionMet) {
            $eventsData = $this.MonitorEventObject.GetRawEventData()
            foreach ($eventData in $eventsData) {
                $doc = [xml]$eventData.ToXml()
                $tag = $doc.Event.UserData.EventXML.Tag
                $dbGUID = $doc.Event.UserData.EventXML.DatabaseGuid.Trim(@('{', '}')).ToUpper()
                if ($this.TagIDs.Contains($tag)) {
                    $this.WriteVerboseWriter("Ignoring failure item with tag: {0}" -f $tag)
                    continue
                }
                if ($this.FilterByDBGuidEnabled -and
                    (!($this.DatabaseGUIDsToMonitor.Contains($dbGUID)))) {
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

        while ($true) {
            if ($this.MonitorEvents() -eq [MDBFailureItemTag.StatusCode]::ConditionMet) {
                return [MDBFailureItemTag.StatusCode]::ConditionMet
            } else {
                Start-Sleep 5
            }
        }
    }

    return $failureItemTagMonitor
}