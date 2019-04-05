#Dump-StoreWorkerOnMonitors
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$DumpFolder = "C:\Data",
[Parameter(Mandatory=$false)][string]$ProcdumpBinary = "C:\Data\Procdump.exe",
[Parameter(Mandatory=$false)][string]$DumpType = "MP",
[Parameter(Mandatory=$false)][bool]$EnablePerformanceCounterMonitor = $true,
[Parameter(Mandatory=$false)][string]$DBWatchCounter = "\MSExchangeIS store({0})\rpc operations/sec",
[Parameter(Mandatory=$false)][array]$ActiveDatabaseNames,
[Parameter(Mandatory=$false)][bool]$EnableEventLogMonitor = $true, 
[Parameter(Mandatory=$false)][array]$EventLogIDs = @(38,39),
[Parameter(Mandatory=$false)][array]$ActiveDatabaseGUIDs,
[Parameter(Mandatory=$false)][int]$PIDRefreshInterval = 600,
[Parameter(Mandatory=$false)][int]$SleepMilliseconds = 100,
[Parameter(Mandatory=$false)][bool]$EnableExperfwizManager = $true,
[Parameter(Mandatory=$false)][int]$ExperfwizInterval = 1,
[Parameter(Mandatory=$false)][string]$ExperfwizSaveLocation = "C:\Data",
[Parameter(Mandatory=$false)][bool]$ScriptDebug = $true
)

$scriptVersion = 0.1

$display = @"

    Monitor on Event Log v{0}

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"@ -f $scriptVersion

########################
#
# Template Functions
#
########################

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


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-LoggerObject/New-LoggerObject.ps1
Function New-LoggerObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogDirectory = ".",
[Parameter(Mandatory=$false)][string]$LogName = "Script_Logging",
[Parameter(Mandatory=$false)][bool]$OverWriteLog = $false,
[Parameter(Mandatory=$false)][bool]$EnableDateTime = $true,
[Parameter(Mandatory=$false)][bool]$IncludeDateTimeToFileName = $true,
[Parameter(Mandatory=$false)][int]$MaxFileSizeInMB = 10,
[Parameter(Mandatory=$false)][int]$CheckSizeIntervalMinutes = 10,
[Parameter(Mandatory=$false)][int]$NumberOfLogsToKeep = 10,
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
# New-LoggerObject -- Template Functions
#
########################

Function Write-ToLog {
param(
[string]$WriteString,
[string]$LogLocation
)
    $WriteString | Out-File ($LogLocation) -Append
}

########################
#
# End New-LoggerObject -- Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($LogDirectory -eq ".")
{
    $LogDirectory = (Get-Location).Path
}
if([string]::IsNullOrWhiteSpace($LogName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogName" 
}
if(!(Test-Path $LogDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogDirectory" 
}

$loggerObject = New-Object pscustomobject 
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $LogDirectory
$loggerObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $LogName
$loggerObject | Add-Member -MemberType NoteProperty -Name "FullPath" -Value $fullLogPath
$loggerObject | Add-Member -MemberType NoteProperty -Name "InstanceBaseName" -Value ([string]::Empty)
$loggerObject | Add-Member -MemberType NoteProperty -Name "EnableDateTime" -Value $EnableDateTime
$loggerObject | Add-Member -MemberType NoteProperty -Name "IncludeDateTimeToFileName" -Value $IncludeDateTimeToFileName
$loggerObject | Add-Member -MemberType NoteProperty -Name "MaxFileSizeInMB" -Value $MaxFileSizeInMB
$loggerObject | Add-Member -MemberType NoteProperty -Name "CheckSizeIntervalMinutes" -Value $CheckSizeIntervalMinutes
$loggerObject | Add-Member -MemberType NoteProperty -Name "NextFileCheckTime" -Value ((Get-Date).AddMinutes($CheckSizeIntervalMinutes))
$loggerObject | Add-Member -MemberType NoteProperty -Name "InstanceNumber" -Value 1
$loggerObject | Add-Member -MemberType NoteProperty -Name "NumberOfLogsToKeep" -Value $NumberOfLogsToKeep
$loggerObject | Add-Member -MemberType ScriptMethod -Name "ToLog" -Value ${Function:Write-ToLog}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}

if($HostFunctionCaller -ne $null)
{
    $loggerObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $loggerObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteHost" -Value {
    param(
    [string]$LoggingString
    )
    if([string]::IsNullOrWhiteSpace($LoggingString))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LoggingString"
    }

    if($this.EnableDateTime)
    {
        $LoggingString = "[{0}] : {1}" -f [System.DateTime]::Now, $LoggingString
    }

    $this.WriteHostWriter($LoggingString)
    $this.ToLog($LoggingString, $this.FullPath)
    $this.LogUpKeep()
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerbose" -Value {
    param(
    [string]$LoggingString
    )
    if([string]::IsNullOrWhiteSpace($LoggingString))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LoggingString"
    }

    if($this.EnableDateTime)
    {
        $LoggingString = "[{0}] : {1}" -f [System.DateTime]::Now, $LoggingString
    }
    $this.WriteVerboseWriter($LoggingString)
    $this.ToLog($LoggingString, $this.FullPath)
    $this.LogUpKeep() 

}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "UpdateFileLocation" -Value{

    if($this.FullPath -eq $null)
    {
        if($this.IncludeDateTimeToFileName)
        {
            $this.InstanceBaseName = "{0}_{1}" -f $this.FileName, ((Get-Date).ToString('yyyyMMddHHmmss'))
            $this.FullPath = "{0}\{1}.txt" -f $this.FileDirectory, $this.InstanceBaseName
        }
        else 
        {
            $this.InstanceBaseName = "{0}" -f $this.FileName
            $this.FullPath = "{0}\{1}.txt" -f $this.FileDirectory, $this.InstanceBaseName
        }
    }
    else 
    {

        do{
            $this.FullPath = "{0}\{1}_{2}.txt" -f $this.FileDirectory, $this.InstanceBaseName, $this.InstanceNumber
            $this.InstanceNumber++
        }while(Test-Path $this.FullPath)
        $this.WriteVerbose("Updated to New Log")
    }
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "LogUpKeep" -Value {

    if($this.NextFileCheckTime -gt [System.DateTime]::Now)
    {
        return 
    }
    $this.NextFileCheckTime = (Get-Date).AddMinutes($this.CheckSizeIntervalMinutes)
    $this.CheckFileSize()
    $this.CheckNumberOfFiles()
    $this.WriteVerbose("Did Log Object Up Keep")
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "CheckFileSize" -Value {

    $item = Get-ChildItem $this.FullPath
    if(($item.Length / 1MB) -gt $this.MaxFileSizeInMB)
    {
        $this.UpdateFileLocation()
    }
}

$loggerObject | Add-Member -MemberType ScriptMethod -Name "CheckNumberOfFiles" -Value {

    $filter = "{0}*" -f $this.InstanceBaseName
    $items = Get-ChildItem -Path $this.FileDirectory | ?{$_.Name -like $filter}
    if($items.Count -gt $this.NumberOfLogsToKeep)
    {
        do{
            $items | Sort-Object LastWriteTime | Select -First 1 | Remove-Item -Force 
            $items = Get-ChildItem -Path $this.FileDirectory | ?{$_.Name -like $filter}
        }while($items.Count -gt $this.NumberOfLogsToKeep)
    }
}

$loggerObject.UpdateFileLocation()
try 
{
    "[{0}] : Creating a new logger instance" -f [System.DAteTime]::Now | Out-File ($loggerObject.FullPath) -Append
}
catch 
{
    throw 
}

return $loggerObject
}
# End Function New-LoggerObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-LocalStoreWorkerPIDCache/New-LocalStoreWorkerPIDCache.ps1
#New-LocalStoreWorkerPIDCache
Function New-LocalStoreWorkerPIDCache {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][array]$MonitorDBsGUID,
[Parameter(Mandatory=$false)][array]$MonitorDBsName,
[Parameter(Mandatory=$false)][int]$UpdateCacheInterval = 300,
[Parameter(Mandatory=$false)][bool]$WriteVerboseData = $false,
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
# New-LocalStoreWorkerPIDCache -- Template Functions
#
########################


########################
#
# End New-LocalStoreWorkerPIDCache -- Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if(($MonitorDBsGUID -eq $null -or $MonitorDBsGUID.Count -eq 0) -and ($MonitorDBsName -eq $null -or $MonitorDBsName.Count -eq 0))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide either a valid monitor MonitorDBsGUID or MonitorDBsName" 
}
if($UpdateCacheInterval -eq $null -or ($UpdateCacheInterval -lt 60 -or $UpdateCacheInterval -gt 3600))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide either a valid UpdateCacheInterval. Must be a value between 60 and 3600"
}

if($MonitorDBsGUID -ne $null -and $MonitorDBsGUID.Count -gt 0)
{
    $MonitorByGUIDs = $true 
}
if($MonitorDBsName -ne $null -and $MonitorDBsName -gt 0)
{
    $MonitorByNames = $true 
}


Function Save-MonitorByGUIDs {
    $upperGUID = @()
    foreach($guid in $MonitorDBsGUID)
    {
        $upperGUID += $guid.ToUpper()
    }
    return $upperGUID
}

$localStoreWorkerPIDCache = New-Object pscustomobject 
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

if($HostFunctionCaller -ne $null)
{
    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}

if($VerboseFunctionCaller -ne $null)
{
    $localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}


$localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdateCacheTime" -Value {
    $this.NextUpdateTime = ([System.DateTime]::Now).AddSeconds($this.UpdateCacheInterval)
}

$localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdatePIDCache" -Value {

    $this.WriteVerboseWriter("Calling Update PID Cache") 
    if($this.MonitorByGUIDs)
    {
        $this.WriteVerboseWriter("Monitor by GUIDs is enabled updating the PID via Process ID command line")
        $this.PIDCacheGUID = @{}
        $allStoreWorkers = Get-WmiObject Win32_Process -Filter "Name = 'Microsoft.Exchange.Store.Worker.exe'"
        foreach($worker in $allStoreWorkers)
        {
            $commandLine = $worker.CommandLine 
            if($commandLine -ne $null)
            {
                $dbGUID = ($commandLine.Substring(($start = $commandLine.IndexOf("-id:") + 4), $commandLine.IndexOf(" ", $start) - $start)).ToUpper()
                if($this.MonitorDBsGUID.Contains($dbGUID))
                {
                    $workerPID = $worker.ProcessId
                    $this.WriteVerboseWriter("Adding GUID: {0}" -f $dbGUID)
                    $this.WriteVerboseWriter("Value PID: {0}" -f $workerPID)
                    $this.PIDCacheGUID.Add($dbGUID,$workerPID)
                }
                else 
                {
                    $this.WriteVerboseWriter("Failed to find GUID '{0}' in the list to monitor" -f $dbGUID) 
                }
            }
            else
            {
                $this.WriteVerboseWriter("Command Line is null. Failed to determine what PID '{0}' belongs to" -f $worker.ProcessId)
            }
        }
    }
    if($this.MonitorByNames)
    {
        $this.PIDCacheNames = @{}
        foreach($db in $this.MonitorDBsName)
        {
            $counter = "\MSExchangeIS store({0})\Process ID" -f $db 
            $workerPID = (Get-Counter -Counter $counter).CounterSamples.CookedValue
            $this.PIDCacheNames.Add($db, $workerPID)
        }
    }

    $this.UpdateCacheTime()  
}

$localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "UpdatePIDCacheIfNeeded" -Value {
    if([System.DateTime]::Now -gt $this.NextUpdateTime)
    {
        $this.UpdatePIDCache()
    }
}

$localStoreWorkerPIDCache | Add-Member -MemberType ScriptMethod -Name "GetPIDNow" -Value {
    param(
    [string]$DBLookup
    )

    if([string]::IsNullOrWhiteSpace($DBLookup))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide DBLookup"
    }
    
    #GUID length 
    if($DBLookup.Length -eq 36)
    {
        return $this.PIDCacheGUID[$DBLookup]
    }
    else 
    {
        return $this.PIDCacheNames[$DBLookup]
    }

}

$localStoreWorkerPIDCache.UpdatePIDCache() 

return $localStoreWorkerPIDCache
}
# End Function New-LocalStoreWorkerPIDCache


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-MDBFailureItemTagMonitor/New-MDBFailureItemTagMonitor.ps1
Function New-MDBFailureItemTagMonitor {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][array]$TagIDs = @(38,39),
[Parameter(Mandatory=$false)][array]$MonitorOnlyDBs,
[Parameter(Mandatory=$false)][bool]$WriteVerboseData,
[Parameter(Mandatory=$false)][object]$LoggerObject,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.3
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
    if($this.LoggerObject -ne $null)
    {
        $this.LoggerObject.WriteVerbose($WriteString)
    }
    elseif($this.VerboseFunctionCaller -eq $null -and $this.WriteVerboseData)
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
# New-MDBFailureItemTagMonitor -- Template Functions
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
# End New-MDBFailureItemTagMonitor -- Template Functions
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
$failureItemTagMonitor | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
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

# End Function New-MDBFailureItemTagMonitor



# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-PerformanceCounterMonitorThresholdObject/New-PerformanceCounterMonitorThresholdObject.ps1
Function New-PerformanceCounterMonitorThresholdObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$Perfcounters,
[Parameter(Mandatory=$false)][int]$SampleInterval = 1,
[Parameter(Mandatory=$false)][int]$MaxSamples = 10,
[Parameter(Mandatory=$false)][int]$SleepTime = 0,
[Parameter(Mandatory=$false)][int]$UpdateEveryXMinutes = 5,
[Parameter(Mandatory=$false)][object]$LoggerObject,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)
<#
This works remotely as well 
[hashtable]$Perfcounters
    [Key = \\serverName\logicaldisk(c:)\avg. disk sec/write]
        [value]
            [double]AverageThreshold
            [double]MaxSpikeThreshold
            [double]MinDipThreshold
            [string]ThresholdType - GreaterThan/LessThan
#>

#Function Version 1.4
if($SampleInterval -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SampleInterval. Provide a value greater than 1."
}
if($MaxSamples -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSamples. Provide a value greater than 1."
}
if($UpdateEveryXMinutes -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid UpdateEveryXMinutes. Provide a value greater than 1"
}

foreach($key in $Perfcounters.Keys)
{
    try 
    {
        Get-Counter -Counter $key -ErrorAction stop | Out-Null
    }
    catch 
    {
        $info = "Failed to provide valid key '{0}'. Error: {1}" -f $key, ($Error[0].Exception)
        throw [System.Management.Automation.ParameterBindingException] $info 
    }
    if([string]::IsNullOrEmpty($Perfcounters[$key].ThresholdType) -or ($Perfcounters[$key].ThresholdType -ne "GreaterThan" -and $Perfcounters[$key].ThresholdType -ne "LessThan"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a ThresholdType property with a string value of 'GreaterThan' or 'LessThan'"
    }
    if($Perfcounters[$key].AverageThreshold -eq $null -or $Perfcounters[$key].AverageThreshold.Gettype().Name -ne "Double")
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a AverageThreshold property with a double type value." 
    }
    if(($Perfcounters[$key].ThresholdType -eq "GreaterThan") -and (($Perfcounters[$key].MaxSpikeThreshold -eq $null -or $Perfcounters[$key].MaxSpikeThreshold.Gettype().Name -ne "Double")))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a MaxSpikeThreshold property with a double type value, when ThresholdType is set to GreaterThan." 
    }
    if(($Perfcounters[$key].ThresholdType -eq "LessThan") -and ($Perfcounters[$key].MinDipThreshold -eq $null -or $Perfcounters[$key].MinDipThreshold.Gettype().Name -ne "Double"))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Perfcounters object. Need to provide a MinDipThreshold property with a double type value, when ThresholdType is set to LessThan." 
    }
}

Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($this.LoggerObject -ne $null)
        {
            $this.LoggerObject.WriteVerbose($WriteString)
        }
        elseif($this.VerboseFunctionCaller -eq $null)
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


Add-Type -TypeDefinition @"
    namespace PerfCounterMonitor
    {
        public enum StatusCode
        {
            None,
            Passed,
            ThresholdMet
        }
    }

"@ 

Function Get-Counters {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[System.Object]])]

    [System.Collections.Generic.List[System.Object]]$counterList = New-Object -TypeName System.Collections.Generic.List[System.Object]
    foreach($key in $Perfcounters.Keys)
    {
        $counterList.Add($key)
    }

    return $counterList
}

Function Get-ThresholdMetObjectDetails {
    $obj = New-Object pscustomobject 
    $obj | Add-Member -MemberType NoteProperty -Name "Counter" -Value ([string]::Empty)
    $obj | Add-Member -MemberType NoteProperty -Name "MetValue" -Value ([double]0)
    $obj | Add-Member -MemberType NoteProperty -Name "Details" -Value ([string]::Empty)
    $obj | Add-Member -MemberType NoteProperty -Name "Type" -Value ([string]::Empty)
    return $obj
}

$perfMonitorObject = New-Object pscustomobject 

$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "PerformanceCounters" -Value $Perfcounters
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "MaxSamples" -Value $MaxSamples
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepTime" -Value $SleepTime
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "Counters" -Value (Get-Counters)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetDetails" -Value ([string]::Empty)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetObjectDetails" -Value (Get-ThresholdMetObjectDetails)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}



if($HostFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

#Master Template https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-PerformanceCounterMinMaxAverageCorrectly/Get-PerformanceCounterMinMaxAverageCorrectly.ps1
$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetPerformanceCounterMinMaxAverageCorrectly" -Value {

[CmdletBinding()]
param(
[object]$PerformanceCounterSamples
)

<#
Calculate Averages 
Average calculation for Average counters taken from these references:
https://msdn.microsoft.com/en-us/library/ms804010.aspx
https://blogs.msdn.microsoft.com/ntdebugging/2013/09/30/performance-monitor-averages-the-right-way-and-the-wrong-way/

[arrayorlist]PerformanceCounterSamples
    CookedValue
    RawValue
    TimeBase
    SecondValue
    CounterType
#>
    
    #Function Version 1.0
    if($PerformanceCounterSamples -eq $null -or $PerformanceCounterSamples.Count -le 1)
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PerformanceCounterSamples. Provide more than 1 sample as well."
    }

    $min = [int64]::MaxValue
    $max = [int64]::MinValue

    foreach($sample in $PerformanceCounterSamples)
    {
        if($sample.CookedValue -lt $min) {$min = $sample.CookedValue}
        if($sample.CookedValue -gt $max) {$max = $sample.CookedValue}
    }

    if($PerformanceCounterSamples[0].CounterType -like "AverageTimer*")
    {
        $numTicksDiff = $PerformanceCounterSamples[-1].RawValue - $PerformanceCounterSamples[0].RawValue
        $frequency = $PerformanceCounterSamples[-1].TimeBase
        $numOpsDif = $PerformanceCounterSamples[-1].SecondValue
        if($frequency -ne 0 -and $numTicksDiff -ne 0 -and $numOpsDif -ne 0)
        {
            $avg = (($numTicksDiff/ $frequency) / $numOpsDif)
        }
        else 
        {
            $avg = 0
        }
    }
    else 
    {
        $avg = ($PerformanceCounterSamples | Measure-Object -Property CookedValue -Average).Average
    }

    $minMaxAvgObj = New-Object pscustomobject

    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Min" -Value $min
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Max" -Value $max
    $minMaxAvgObj | Add-Member -MemberType NoteProperty -Name "Avg" -Value $avg

    return $minMaxAvgObj
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "WriteUpdate" -Value {

    if([DateTime]::Now -gt $this.NextUpdateTime)
    {
        $this.WriteHostWriter("[{0}] : Everything is passing checks thus far..." -f ([DateTime]$dt = [DateTime]::Now))
        $this.NextUpdateTime = $dt.AddMinutes($this.UpdateMinuteInterval)
    }
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetData" -Value {
    $measure = Measure-Command{$results = (Get-counter -Counter $this.Counters -SampleInterval $this.SampleInterval -MaxSamples $this.MaxSamples).CounterSamples | Group-Object Path}
    $this.WriteVerboseWriter("Took {0} seconds to get the data" -f $measure.TotalSeconds)
    return $results
}

$perfMonitorObject | Add-Member -MemberType ScriptMethod -Name "GetMonitorResults" -Value {
    
    $results = $this.GetData()
    foreach($counterResults in $results)
    {
        $counterName = $counterResults.Name 
        $counterPassedObj = $this.PerformanceCounters[$counterName]
        $minMaxAvgResults = $this.GetPerformanceCounterMinMaxAverageCorrectly($counterResults.Group)
        
        $thresholdType = ([string]::Empty)
        $thresholdValue = 0

        if($counterPassedObj.ThresholdType -eq "GreaterThan")
        {
            if($minMaxAvgResults.Max -ge $counterPassedObj.MaxSpikeThreshold)
            {
                $details = "Met max spike threshold. Current max spike is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Max, $counterPassedObj.MaxSpikeThreshold, $counterName
                $thresholdType = "GreaterThanMax"
                $thresholdValue = $minMaxAvgResults.Max
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -ge $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdType = "GreaterThanAvg"
                $thresholdValue = $minMaxAvgResults.Avg 
                $thresholdMet = $true 
            }
        }
        elseif($counterPassedObj.ThresholdType -eq "LessThan")
        {
            if($minMaxAvgResults.Min -le $counterPassedObj.MinDipThreshold)
            {
                $details = "Met min dip threshold. Current min dip is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Min, $counterPassedObj.MinDipThreshold, $counterName
                $thresholdType = "LessThanMin"
                $thresholdValue = $minMaxAvgResults.Min
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -le $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdType = "LessThanAvg"
                $thresholdValue = $minMaxAvgResults.Avg
                $thresholdMet = $true 
            }   
        }
        if($thresholdMet)
        {
            $this.ThresholdMetDetails = $details
            $this.ThresholdMetObjectDetails.Counter = $counterName
            $this.ThresholdMetObjectDetails.MetValue = $thresholdValue
            $this.ThresholdMetObjectDetails.Details = $details 
            $this.ThresholdMetObjectDetails.Type = $thresholdType
            $this.WriteHostWriter($details)
            return [PerfCounterMonitor.StatusCode]::ThresholdMet
        }
    }
    $this.WriteUpdate()
    Start-Sleep $this.SleepTime
    return [PerfCounterMonitor.StatusCode]::Passed
}

return $perfMonitorObject
}
# End Function New-PerformanceCounterMonitorThresholdObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterFullNameToCounterObjectName/Get-CounterFullNameToCounterObjectName.ps1
Function Get-CounterFullNameToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$FullCounterName
)
    
#Function Version 1.1
$counterObject = New-Object -TypeName pscustomobject 

#\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
$endOfServerIndex = $FullCounterName.IndexOf("\",2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
$startOfCounterIndex = $FullCounterName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
$endOfCounterObjectIndex = $FullCounterName.IndexOf("(") 
if($endOfCounterObjectIndex -eq -1){$endOfCounterObjectIndex = $startOfCounterIndex - 1}
if(($FullCounterName.Contains("(")))
{
    $instanceName = ($FullCounterName.Substring($endOfCounterObjectIndex + 1, ($FullCounterName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
}
$counterObject | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullCounterName
$counterObject | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullCounterName.Substring(2,($endOfServerIndex - 2)))
$counterObject | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullCounterName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObject | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
$counterObject | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullCounterName.Substring($startOfCounterIndex))

return $counterObject

}
# End Function Get-CounterFullNameToCounterObjectName



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

Function Get-PerformanceCountersMonitorThresholdObject {

    Function Get-PerfDataThresholdObject {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "AverageThreshold" -Value ([double]20)
        $obj | Add-Member -MemberType NoteProperty -Name "MinDipThreshold" -Value ([double]-1)
        $obj | Add-Member -MemberType NoteProperty -Name "ThresholdType" -Value "LessThan"
        return $obj
    }

    try 
    {
        $counters = @()
        foreach($db in $ActiveDatabaseNames)
        {
            $counters += $DBWatchCounter -f $db 
        }
        $counterSamples = (Get-Counter -Counter $counters -ErrorAction Stop).CounterSamples
    }
    catch 
    {
        $displayError = ("Failed to get counter for this computer. Error: '{0}'" -f ($Error[0].Exception))
        throw $displayError
    }

    $hash = @{}
    $paths = ($counterSamples | Group Path).Name 
    foreach($path in $paths)
    {
        $hash.Add($path, (Get-PerfDataThresholdObject))
    }

    $perfObj = New-PerformanceCounterMonitorThresholdObject -Perfcounters $hash -MaxSamples 2 -LoggerObject $Script:Logger
    return $perfObj
}

Function Start-Experfwiz {
    if($EnableExperfwizManager)
    {
        $Script:experfwizManager.Start()
    }
}
Function Stop-Experfwiz {
    if($EnableExperfwizManager)
    {
        $Script:experfwizManager.Stop()
    }
}
Function Restart-Experfwiz {
    Stop-Experfwiz
    Start-Experfwiz
}

Function Invoke-MonitorLoop {

    $Script:Logger.WriteVerbose("Entering Invoke-MonitorLoop")
    while($true)
    {
        if($Script:IssueHasOccurred)
        {
            if($EnableExperfwizManager -and $Script:RestartExperfwizTime -lt [System.DateTime]::Now)
            {
                $Script:Logger.WriteVerbose("Restarting Experfwiz due to time lapse")
                Restart-Experfwiz
                $Script:Logger.WriteVerbose("Finished restarting Experfwiz")
                $Script:IssueHasOccurred = $false 
            }
        }
        if($EnablePerformanceCounterMonitor -and $Script:perfMonitor.GetMonitorResults() -eq [PerfCounterMonitor.StatusCode]::ThresholdMet)
        {
            $Script:Logger.WriteHost("Performance Condition Met")
            $Script:MetConditionType = "PerformanceCounter"
            break 
        }
        if($EnableEventLogMonitor -and $Script:eventMonitor.MonitorEvents() -eq [MDBFailureItemTag.StatusCode]::ConditionMet)
        {
            $Script:Logger.WriteHost("Event Log Condition Met")
            $Script:MetConditionType = "EventLog"
            break 
        }
        $Script:PIDCache.UpdatePIDCacheIfNeeded()
        Start-Sleep -Milliseconds $SleepMilliseconds
    }
}

Function Main {
    
    $Script:Logger = New-LoggerObject -LogName "DumpStoreWorkerOnMonitors"
    if($EnablePerformanceCounterMonitor)
    {
        $Script:perfMonitor = Get-PerformanceCountersMonitorThresholdObject
    }
    if($EnableEventLogMonitor)
    {
        $dbGUIDs = @() 
        foreach($db in $ActiveDatabaseGUIDs)
        {
            $dbGUIDs += $db.ToUpper() 
        }
        $Script:eventMonitor = New-MDBFailureItemTagMonitor -MonitorOnlyDBs $dbGUIDs -TagID $EventLogIDs -LoggerObject $Script:Logger
    }
    if($EnableExperfwizManager)
    {
        $Script:experfwizManager = New-ExperfwizManagerObject -ExperfwizDirectory $ExperfwizSaveLocation -Interval $ExperfwizInterval -MaxFileSize 10240
    }

    $Script:MetConditionType = [string]::Empty
    
    $dpType = [string]::Empty
    Switch($DumpType)
    {
        "Mini" {$dpType = [string]::Empty; break;}
        "MP" {$dpType = "-mp"; break}
        "MA" {$dpType = "-ma"; break}
    }
    
    $issueCount = 0
    $Script:PIDCache = New-LocalStoreWorkerPIDCache -MonitorDBsGUID $ActiveDatabaseGUIDs -MonitorDBsName $ActiveDatabaseNames 
    $Script:IssueHasOccurred = $false
    Start-Experfwiz
    while($issueCount -lt 10)
    {

        Invoke-MonitorLoop 
        
        switch ($Script:MetConditionType)
        {
            "PerformanceCounter" {
                $thresholdMetCounter = $Script:perfMonitor.ThresholdMetObjectDetails.Counter
                $counterObject = Get-CounterFullNameToCounterObjectName -FullCounterName $thresholdMetCounter
                $instance = $counterObject.InstanceName
                $workerPID = $Script:PIDCache.GetPIDNow($instance) 
            }
            "EventLog" {
                $dbGuid = $Script:eventMonitor.ConditionMetDB
                $workerPID = $Script:PIDCache.GetPIDNow($dbGuid)
            }
        }
        $Script:Logger.WriteHost("PID: {0}" -f $workerPid)
        & $ProcdumpBinary $dpType $workerPid $DumpFolder -accepteula 
        $Script:Logger.WriteHost("Finished dumpping the process")
        $Script:eventMonitor.ResetStatus()
        $Script:PIDCache.UpdatePIDCache() 
        $Script:RestartExperfwizTime = (Get-Date).AddMinutes(10)
        $Script:IssueHasOccurred = $true 
        $issueCount++ 
        sleep 1
    }
    $Script:Logger.WriteHost("Issue Limit Reached. Waiting some time before we stop experfwiz")
    sleep 120
    Stop-Experfwiz
}
####### Check for Parameter Issues ##########

if(-not(Test-Path $DumpFolder))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DumpFolder. Provide a path that exists."
}
if((-not(Test-Path $ProcdumpBinary)) -and (-not($ProcdumpBinary.EndsWith("Procdump.exe"))))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ProcdumpBinary. Provide the full path to Procdump.exe."
}
if([string]::IsNullOrWhiteSpace($DumpType) -or ((-not($DumpType -eq "Mini") -and (-not($DumpType -eq "MP")) -and (-not($DumpType -eq "MA")))))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DumpType. Provide 'Mini', 'MP', or 'MA'"
}
if(($ActiveDatabaseNames -eq $null) -or $ActiveDatabaseNames.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ActiveDatabaseNames. Provide an array of DB Names"
}
if($PIDRefreshInterval -lt 30 -or $PIDRefreshInterval -gt 3600)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid PIDRefreshInterval. Provide a value between 30 and 3600"
}
if($SleepMilliseconds -lt 100 -or $SleepMilliseconds -gt 10000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SleepMilliseconds. Provide a value between 100 and 10000"
}
if($EnableExperfwizManager -and (!(Test-Path "Experfwiz.ps1")))
{
    throw [System.Management.Automation.ParameterBindingException] "Experfwiz.ps1 isn't located in this directory."
}

Write-Host $display
Main
