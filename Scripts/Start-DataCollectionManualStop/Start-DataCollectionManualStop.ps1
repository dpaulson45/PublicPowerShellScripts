[CmdletBinding()]
param(
[string]$SaveAllDataPath = ((Get-Location).Path),
[array]$Servers = @($ENV:COMPUTERNAME),
[bool]$EnableExtraTracing,
[array]$ExtraTraceConfigFileContent,
[bool]$EnableNetshTracing,
[int]$NetshTraceMaxSize = 2048,
[string]$NetshProviderString,
[string]$NetshScenario = "netconnection",
[switch]$StopDataCollectors
)

$scriptVersion = 0.1

$display = @"

    Data Collection on Manual Start and Stop v{0}

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

"@ -f $scriptVersion

$scriptConfig = "{0}\{1}.config" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), (Split-Path -Leaf $MyInvocation.MyCommand.Path)

#############################
#
# Template Functions 
#
#############################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Confirm-Administrator/Confirm-Administrator.ps1
Function Confirm-Administrator {
    #Function Version 1.1
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
    if($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))
    {
        return $true 
    }
    else 
    {
        return $false 
    }
}
# End Function Confirm-Administrator


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-ScriptConfigFile/Import-ScriptConfigFile.ps1
Function Import-ScriptConfigFile {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ScriptConfigFileLocation,
[Parameter(Mandatory=$false)][string]$MainSplitLineValue = "~"
)

#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>

Write-VerboseWriter("Calling: Import-ScriptConfigFile")
Write-VerboseWriter("Passed: [string]ScriptConfigFileLocation: {0} | [string]MainSplitLineValue: {1}" -f $ScriptConfigFileLocation, $MainSplitLineValue)

Function Get-SystemConvertValue{
param(
[Parameter(Mandatory=$true)][string]$Value,
[Parameter(Mandatory=$true)][string]$Type
)
    Write-VerboseWriter("Calling: Get-SystemConvertValue")
    Write-VerboseWriter("Passed: [string]Value: {0} | [string]Type: {1}" -f $Value, $Type)
    if($Type -eq "int")
    {
        $variableValue = [System.Convert]::ToInt32($Value)
    }
    elseif($Type -eq "double")
    {
        $variableValue = [System.Convert]::ToDouble($Value)
    }
    elseif($Type -eq "int64")
    {
        $variableValue = [System.Convert]::ToInt64($Value)
    }

    return $variableValue
}

if(!(Test-Path $ScriptConfigFileLocation))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ScriptConfigFileLocation" 
}
$readContent = Get-Content $ScriptConfigFileLocation 

foreach($line in $readContent)
{
    Write-VerboseWriter("Working on line: {0}" -f $line)
    $splitInfo = $line.Split($MainSplitLineValue)
    $variableName = $splitInfo[0] 
    $fullVariableType = $splitInfo[1]
    $variableValue = $splitInfo[2]

    if($fullVariableType -like "GetContent*")
    {
        Write-VerboseWriter("Detected GetContent")
        if(Test-Path $variableValue)
        {
            $variableValue = Get-Content $variableValue
        }
        else 
        {
            Write-VerboseWriter("Failed to find {0}. Going to move on." -f $variableValue)
            continue 
        }
    }
    elseif($fullVariableType -like "array*")
    {
        Write-VerboseWriter("Detected array")
        $variableTypeSplit = $fullVariableType.Split("=")
        $type = $variableTypeSplit[1]
        $splitArrayValue = $variableTypeSplit[2]
        $variableValue = $variableValue.Split($splitArrayValue)
        if($type -ne "string")
        {
            Write-VerboseWriter("Determined array isn't a string type converting")
            $tempArray = @()
            foreach($value in $variableValue)
            {
                $tempArray += Get-SystemConvertValue -Value $value -Type $type 
            }

            $variableValue = $tempArray 
        }
    }
    elseif($fullVariableType -like "bool*")
    {
        Write-VerboseWriter("Detected boolean type")
        if($variableValue -eq "false")
        {
            $variableValue = $false 
        }
        else 
        {
            $variableValue = $true 
        }
    }
    elseif($fullVariableType -eq "int" -or 
    $fullVariableType -eq "double" -or 
    $fullVariableType -eq "int64")
    {
        Write-VerboseWriter("Detected a number type value")
        $variableValue = Get-SystemConvertValue -Value $variableValue -Type $fullVariableType 
    }
    Set-Variable -Name $variableName -Value $variableValue -Scope Script 
}

}
# End Function Import-ScriptConfigFile


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-ExtraLogmanObject/New-ExtraLogmanObject.ps1
Function New-ExtraLogmanObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogmanName = "ExchangeLogman",
[Parameter(Mandatory=$false)][string]$FileName,
[Parameter(Mandatory=$false)][int]$EtlFileSize = 400,
#[Parameter(Mandatory=$false)][string]$EtlCNF, # = "00:30:00", #TODO see if this is truly needed
[Parameter(Mandatory=$false)][string]$FileDirectory = "C:\Traces",
[Parameter(Mandatory=$false)][string]$Provider = "Microsoft Exchange Server 2010",
[Parameter(Mandatory=$false)][string]$AppendVersioningToFile = "mmddhhmm",
[Parameter(Mandatory=$false)][array]$Servers,
[Parameter(Mandatory=$false)][array]$ExtraTraceConfigFileContent
)

#Function Version 1.3
if([string]::IsNullOrEmpty($LogmanName.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName" 
}
if($EtlFileSize -lt 100 -or $EtlFileSize -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 1000"
}
if([string]::IsNullOrEmpty($FileDirectory.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileDirectory" 
}
if([string]::IsNullOrEmpty($Provider.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider" 
}
if([string]::IsNullOrEmpty($AppendVersioningToFile.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
}
if($Servers -eq $null -or $Servers.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Servers"
}
if($ExtraTraceConfigFileContent -eq $null -or $ExtraTraceConfigFileContent.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExtraTraceConfigFileContent"
}
if([string]::IsNullOrEmpty($FileName.Trim()))
{
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
    foreach($server in $Servers)
    {
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

        $hasher.Add($server,$statusObject)
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
    [Parameter(Mandatory=$true)][string]$Line 
    )
        $Line | Out-File -FilePath "C:\EnabledTraces.Config" -Encoding ascii -Append
    }

    $content = $this.ExtraTraceConfigFileContent
    New-Item -Path "C:\EnabledTraces.Config" -ItemType File -Force | Out-Null
    foreach($line in $content)
    {
        Save-ExtraLine $line
    }

    $servers = $this.Servers
    foreach($server in $servers)
    {
        if($server -ne $Env:COMPUTERNAME)
        {
            try 
            {
                Copy-Item "C:\EnabledTraces.Config" "\\$server\C$\EnabledTraces.Config" -ErrorAction Stop
                $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
            }
            catch 
            {
                $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Failed
                $failureCount++
            }
        }
        #creating the file shouldn't be an issue locally 
        else 
        {
            $this.ServersStatus[$server].ExtraConfigWasSaved = [ExtraLogman.StatusCode]::Success
        }
    }

    if($failureCount -ne 0)
    {
        return [ExtraLogman.StatusCode]::SingleServerFailure
    }
    return [ExtraLogman.StatusCode]::Success
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StartLogman" -Value {
    $servers = $this.Servers
    $logman = $this.TraceName
    $failureCount = 0
    foreach($server in $servers)
    {
        [array]$results = logman start $logman -s $server
        $this.ServersStatus[$server].StartedResults = $results
        if(($results[-1]).Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StartedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }
    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    $servers = $this.Servers
    $logman = $this.TraceName
    $failureCount = 0 
    foreach($server in $servers)
    {
        [array]$results = logman stop $logman -s $server
        $this.ServersStatus[$server].StoppedResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StoppedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "DeleteLogman" -Value {
    $servers = $this.Servers 
    $logman = $this.TraceName 
    $failureCount = 0
    foreach($server in $servers)
    {
        [array]$results = logman delete $logman -s $server
        $this.ServersStatus[$server].DeletedResults = $results
        $this.ServersStatus[$server].LogmanStatus = ([string]::Empty)
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].DeletedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
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
    foreach($server in $servers)
    {
        $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
        [array]$results = logman create trace $logman -max $maxSize -v $appendVersion -o $fullFileName -p $provider -s $server -bs 128 -f bincirc -mode globalsequence
        $this.ServersStatus[$server].CreatedResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
        }
        elseif($results[-1].Trim() -eq "Data Collector already exists.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::DataCollectorExists
            $failureCount++ #for now count this as a failure. 
        }
        else 
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0 {return [ExtraLogman.StatusCode]::Success}
        {($failureCount -eq $servers.count)} {return [ExtraLogman.StatusCode]::AllFailure}
        default {return [ExtraLogman.StatusCode]::SingleServerFailure}
    }
}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "CheckLogmanStatus" -Value {
    $servers = $this.Servers 
    $logman = $this.TraceName 
    foreach($server in $servers)
    {
        [array]$results = logman $logman -s $server 
        
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::Success
            $i = 2 
            if(-not ($results[$i].StartsWith("Status:")))
            {
                $i = 0 
                while($i -lt $results.count)
                {
                    if(($results[$i].StartsWith("Status:")))
                    {
                        break 
                    }
                    $i++ 
                }
            }
            $lineStatus = $results[$i].Replace("Status:","").Trim()
            $this.ServersStatus[$server].LogmanStatus = $lineStatus
            if($lineStatus -eq "running")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Running
            }
            elseif($lineStatus -eq "stopped")
            {
                $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::Stopped
            }
        }
        else 
        {
            $this.ServersStatus[$server].CreatedStatusCode = [ExtraLogman.StatusCode]::NotFound
            $this.ServersStatus[$server].LogmanStatusCode = [ExtraLogman.StatusCode]::None
        }
    }
    #For now, this should always return success 
    return ([ExtraLogman.StatusCode]::Success)
}

return $logmanObject 
}
# End Function New-ExtraLogmanObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-NetshTraceObject/New-NetshTraceObject.ps1
Function New-NetshTraceObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$ServerList,
[Parameter(Mandatory=$false)][string]$Scenario = "netconnection",
[Parameter(Mandatory=$false)][string]$CustomProviderString, #Custom provider string needs to be done like this, otherwise PowerShell fails to find the provider: provider='{EB004A05-9B1A-11D4-9123-0050047759BC}' keywords=0x3fffffff level=0x7
[Parameter(Mandatory=$false)][string]$Persistent = "Yes",
[Parameter(Mandatory=$false)][string]$BaseFileName = "NetworkCapture",
[Parameter(Mandatory=$false)][string]$SaveDirectory = "C:\",
[Parameter(Mandatory=$false)][int]$MaxSize = 2048,
[Parameter(Mandatory=$false)][string]$Capture = "Yes", 
[Parameter(Mandatory=$false)][string]$Report = "Yes",
[Parameter(Mandatory=$false)][string]$Correlation = "No",
[Parameter(Mandatory=$false)][string]$FileMode = "circular",
[Parameter(Mandatory=$false)][string]$Overwrite = "Yes",
[Parameter(Mandatory=$false)][bool]$WriteVerboseData = $false,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.1
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
##############################
#
#    Script Functions
#
##############################
Function New-ServerStatusHashtable {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server, ([NetshTraceObject.StatusCode]::None))
    }
    return $hasher
}

Function New-ServerStatusDetailsHashtables {
    $hasher = @{}
    foreach($server in $ServerList)
    {
        $hasher.Add($server, "None")
    }
    return $hasher
}

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
$usingCustomProviderString = $false 
if(!([string]::IsNullOrEmpty($CustomProviderString)))
{
    $usingCustomProviderString = $true
}
if([string]::IsNullOrEmpty($Scenario) -and (!($usingCustomProviderString)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Scenario"
}
if($Persistent -ne "Yes" -and $Persistent -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Persistent. Needs to be 'Yes' or 'no'" 
}
if([string]::IsNullOrEmpty($BaseFileName))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BaseFileName"
}
if([string]::IsNullOrEmpty($SaveDirectory))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SaveDirectory"
}
if($MaxSize -lt 0 -or $MaxSize -gt (10 * 1MB))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSize. Provide a value between 0 and 10240 MB"
}
if($Capture -ne "Yes" -and $Capture -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Capture. Needs to be 'Yes' or 'No'"
}
if($Report -ne "Yes" -and $Report -ne "No" -and $Report -ne "Disabled")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Report. Needs to be 'Yes' or 'No' or 'Disabled'"
}
if($Correlation -ne "Yes" -and $Correlation -ne "No" -and $Correlation -ne "Disabled")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Correlation. Needs to be 'Yes' or 'No' or 'Disabled'"
}
if($FileMode -ne "Single" -and $FileMode -ne "Circular" -and $FileMode -ne "append")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid FileMode. Needs to be 'Single' or 'Circular' or 'Append'"
}
if($Overwrite -ne "Yes" -and $Overwrite -ne "No")
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Overwrite. Needs to be 'Yes' or 'No'"
}

$netshTraceObj = New-Object pscustomobject 

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
$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}
$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}


if($HostFunctionCaller -ne $null)
{
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $netshTraceObj | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}


$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartJobManager" -Value {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][array]$ServersWithArguments,
[Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
[Parameter(Mandatory=$false)][string]$JobBatchName,
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJob = $false,
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJobInVerboseFunction, 
[Parameter(Mandatory=$false)][bool]$DisplayReceiveJobInCorrectFunction,
[Parameter(Mandatory=$false)][bool]$NeedReturnData = $true
)

Function Write-ReceiveJobData {
param(
[Parameter(Mandatory=$true)][array]$ReceiveJobData
)
    $returnJob = [string]::Empty
    foreach($job in $ReceiveJobData)
    {
        if($job["Verbose"])
        {
            $this.WriteVerboseWriter($job["Verbose"])
        }
        elseif($job["Host"])
        {
            $this.WriteHostWriter($job["Host"])
        }
        elseif($job["ReturnObject"])
        {
            $returnJob = $job["ReturnObject"]
        }
        else 
        {
            $this.WriteVerboseWriter("Unable to determine the key for the return type.")    
        }
    }
    return $returnJob
}

Function Start-Jobs {
    $this.WriteVerboseWriter("Calling Start-Jobs")
    foreach($serverObject in $ServersWithArguments)
    {
        $server = $serverObject.ServerName
        $argumentList = $serverObject.ArgumentList
        $this.WriteVerboseWriter(("Starting job on server {0}" -f $server))
        Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock -ArgumentList $argumentList -AsJob -JobName $server | Out-Null
    }
}

Function Confirm-JobsPending {
    $jobs = Get-Job
    if($jobs -ne $null)
    {
        return $true 
    }
    return $false
}

Function Wait-JobsCompleted {
    [System.Diagnostics.Stopwatch]$timer = [System.Diagnostics.Stopwatch]::StartNew()
    $returnData = @{}
    while(Confirm-JobsPending)
    {
        $completedJobs = Get-Job | Where-Object {$_.State -ne "Running"}
        if($completedJobs -eq $null)
        {
            Start-Sleep 1 
            continue 
        }

        foreach($job in $completedJobs)
        {
            $receiveJobNull = $false 
            $jobName = $job.Name 
            $receiveJob = Receive-Job $job 
            Remove-Job $job
            if($receiveJob -eq $null)
            {
                $receiveJobNull = $True 
                $this.WriteHostWriter(("Job {0} didn't have any receive job data" -f $jobName))
            }
            if($DisplayReceiveJobInVerboseFunction -and(-not($receiveJobNull)))
            {
                $this.WriteHostWriter(("[JobName: {0}] : {1}" -f $jobName, $receiveJob))
            }
            elseif($DisplayReceiveJobInCorrectFunction -and (-not ($receiveJobNull)))
            {
                $returnJobData = Write-ReceiveJobData -ReceiveJobData $receiveJob
                if($returnJobData -ne $null)
                {
                    $returnData.Add($jobName, $returnJobData)
                }
            }
            elseif($DisplayReceiveJob -and (-not($receiveJobNull)))
            {
                $this.WriteHostWriter($receiveJob)
            }
            if($NeedReturnData -and (-not($DisplayReceiveJobInCorrectFunction)))
            {
                $returnData.Add($job.Name, $receiveJob)
            }
        }
    }
    $timer.Stop()
    $this.WriteVerboseWriter(("Waiting for jobs to complete took {0} seconds" -f $timer.Elapsed.TotalSeconds))
    if($NeedReturnData)
    {
        return $returnData
    }
    return $null 
}

[System.Diagnostics.Stopwatch]$timerMain = [System.Diagnostics.Stopwatch]::StartNew()

Start-Jobs
$data = Wait-JobsCompleted
$timerMain.Stop()
$this.WriteVerboseWriter(("Exiting: Start-JobManager | Time in Start-JobManager: {0} seconds" -f $timerMain.Elapsed.TotalSeconds))
if($NeedReturnData)
{
    return $data
}
return $null
}


$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StopTrace" -Value {
    
    $serversWithArguments = @()
    foreach($server in $this.ServerList)
    {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
        $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
        $serversWithArguments += $obj 
    }
    $this.WriteHostWriter(("[{0}] : Attempting to stop the netsh trace. This may take some time to complete." -f ([datetime]::Now)))
    $scriptBlock = [scriptblock]::Create("netsh trace stop")
    $results = $this.StartJobManager($serversWithArguments, $scriptBlock) 
    $allPassed = $true 
    foreach($server in $this.ServerList)
    {
        $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to stop the trace" -f $server))
        $data = $results[$server]
        $this.ServerStatusDetails[$server] = $data
        $serverSuccess = $false 
        $index = 0 
        if($data[0].Trim() -eq "There is no trace session currently in progress.")
        {
            $serverSuccess = $true 
        }
        elseif($data[3].Trim() -eq "Tracing session was successfully stopped.")
        {
            $serverSuccess = $true 
        }
        else 
        {
            while($index -lt $data.Count)
            {
                if($data[$index].Trim() -eq "Tracing session was successfully stopped.")
                {
                    $serverSuccess = $true 
                    break; 
                }
                $index++
            }
        }
        if($serverSuccess)
        {
            $this.WriteVerboseWriter(("Server {0} appears to have stopped the trace" -f $server))
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to have failed to stop the trace" -f $server))
            $this.WriteVerboseWriter($data)
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
            $allPassed = $false
        }
    }

    if($allPassed)
    {
        return [NetshTraceObject.StatusCode]::Success
    }

    return [NetshTraceObject.StatusCode]::Failed
}

$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "StartTrace" -Value {
    $serversWithArguments = @()
    foreach($server in $this.ServerList)
    {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server
        $obj | Add-Member -MemberType NoteProperty -Name "ArgumentList" -Value ([string]::Empty)
        $serversWithArguments += $obj 
    }

    $this.TraceFile = "{0}\{1}_{2}.etl" -f $this.SaveDirectory, $this.BaseFileName, ((Get-Date).ToString("yyyyMMddHHmmss"))
    $scriptBlockString = "Netsh trace start capture={0} maxsize={1} persistent={2} tracefile={3} correlation={4} overwrite={5} report={6}" -f $this.Capture,
    $this.MaxSize, $this.Persistent, $this.TraceFile, $this.Correlation, $this.Overwrite, $this.Report
    if($this.UsingCustomProvider)
    {
        $scriptBlockString = "{0} {1}" -f $scriptBlockString, $this.CustomProviderString
    }
    else 
    {
        $scriptBlockString = "{0} scenario={1}" -f $scriptBlockString, $this.Scenario
    }
    $this.WriteVerboseWriter(("Full netsh command: '{0}'" -f $scriptBlockString))
    $scriptBlock = [ScriptBlock]::Create($scriptBlockString)

    $results = $this.StartJobManager($serversWithArguments, $scriptBlock)
    $allPassed = $true 
    foreach($server in $this.ServerList)
    {
        $this.WriteVerboseWriter(("Looking at server {0} to see if it worked to start the trace" -f $server))
        $data = $results[$server]
        $this.ServerStatusDetails[$server] = $data
        $index = 0
        if($data.count -lt 3)
        {
            #We either failed or have a netsh trace start need to fail them both out
            $index = -1
        }
        elseif($data[3].StartsWith("Status"))
        {
            $index = 3
        }
        else 
        {
            while($index -lt $data.count)
            {
                if($data[$index].StartsWith("Status"))
                {
                    break;
                }
                $index++
            }
            if($index -eq $data.count)
            {
                $index = -1
            }
        }
        if($index -eq -1 -or (-not($data[$index].Contains("Running"))))
        {
            $this.WriteHostWriter(("Server {0} appears to have failed to start the trace" -f $server))
            $this.WriteHostWriter($data)
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Failed
            $allPassed = $false
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to have started the trace" -f $server))
            $this.ServerStatus[$server] = [NetshTraceObject.StatusCode]::Success 
        }
    }
    if($allPassed)
    {
        return [NetshTraceObject.StatusCode]::Success
    }
    else 
    {
        return [NetshTraceObject.StatusCode]::Failed
    }
}

$netshTraceObj | Add-Member -MemberType ScriptMethod -Name "GetFailedServerStatusDetails" -Value {

    $stringReturnObject = @()
    foreach($server in $this.ServerList)
    {
        if($this.ServerStatus[$server] -eq [NetshTraceObject.StatusCode]::Failed)
        {
            $this.WriteVerboseWriter(("Serer {0} appears to have failed. Collecting the information" -f $server))
            $data = $this.ServerStatusDetails[$server]
            $stringReturnObject += "Server Failed Data: {0}" -f $server
            $stringReturnObject += $data
            $stringReturnObject += "--End--"
            $stringReturnObject += ""
        }
        else 
        {
            $this.WriteVerboseWriter(("Server {0} appears to not have failed." -f $server))
        }
    }
    return $stringReturnObject
}

return $netshTraceObj 
}
# End Function New-NetshTraceObject


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-HostWriter.ps1
#Function Version 1.1
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteHost($WriteString)
    }
    elseif($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}
# End Function Write-HostWriter


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#Function Version 1.1
Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteHost($WriteString)
    }
    elseif($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
# End Function Write-VerboseWriter

Function Create-DataCollections {
    
    if($EnableNetshTracing)
    {
        $Script:netshTracing = New-NetshTraceObject -ServerList $Servers -SaveDirectory $SaveAllDataPath -Scenario $NetshScenario -CustomProviderString $NetshProviderString -MaxSize $NetshTraceMaxSize
    }

    if($EnableExtraTracing)
    {
        $Script:extraTracing = New-ExtraLogmanObject -FileDirectory $SaveAllDataPath -ExtraTraceConfigFileContent $ExtraTraceConfigFileContent -Servers $Servers 
        if($Script:extraTracing.SaveExtraConfigToAllServers() -ne [ExtraLogman.StatusCode]::Success)
        {
            Write-HostWriter("Failed to save out the extra traces config file to all the servers")
            exit
        }
        if($Script:extraTracing.DeleteLogman() -ne [ExtraLogman.StatusCode]::Success)
        {
            #do nothing, we just want to delete it before we attempt to create it again
        }
        if($Script:extraTracing.CreateLogman() -ne [ExtraLogman.StatusCode]::Success)
        {
            Write-HostWriter("Failed to create the logman data collection on all the servers.")
            exit
        }

    }
}

Function Start-DataCollections {
    
    if($EnableExtraTracing -and 
        $Script:extraTracing.StartLogman() -ne [ExtraLogman.StatusCode]::Success)
    {
        Write-HostWriter("Failed to start the extra logman on all the servers.")
        exit
    }

    if($EnableNetshTracing -and 
        $Script:netshTracing.StartTrace() -ne [NetshTraceObject.StatusCode]::Success)
    {
        Write-HostWriter("Failed to start the netsh trace on all the servers. Going to stop all on the servers that might have started.")
        $Script:netshTracing.StopTrace()
        if($EnableExtraTracing)
        {
            Write-HostWriter("Attempting to stop the extra logman on all the servers.")
            if($Script:extraTracing.StopLogman() -ne [ExtraLogman.StatusCode]::Success)
            {
                Write-HostWriter("Failed to stop the extra logman on all the servers.")
            }
            else 
            {
                Write-HostWriter("Successfully stopped extra logman on all the servers.")
            }
        }

        exit
    }

}

Function Stop-DataCollectors {

    if($EnableExtraTracing -and
        $Script:extraTracing.StopLogman() -ne [ExtraLogman.StatusCode]::Success)
    {
        if(!$StopDataCollectors)
        {
            Write-HostWriter("Failed to stop the extra logman on all the servers.")
        }
    }
    if($EnableNetshTracing -and 
        $Script:netshTracing.StopTrace() -ne [NetshTraceObject.StatusCode]::Success)
    {
        if(!$StopDataCollectors)
        {
            Write-HostWriter("Failed to stop the netsh tracing on all the servers.")
        }
    }
}
Function Main {

    if(!(Confirm-Administrator))
    {
        Write-HostWriter("Please run the script as an administrator.")
        exit
    }

    Write-Host $display

    if(Test-Path $scriptConfig)
    {
        Import-ScriptConfigFile -ScriptConfigFileLocation $scriptConfig
    }

    if($StopDataCollectors)
    {
        Write-HostWriter("Stopping the data collections....")
        $netshTraceObject = New-NetshTraceObject -ServerList $Servers
        $netshTraceObject.StopTrace()
        $extraObject = New-ExtraLogmanObject -Servers $Servers -ExtraTraceConfigFileContent $ExtraTraceConfigFileContent
        $extraObject.StopLogman()
        exit
    }

    Write-HostWriter("Creating data collections...")
    Create-DataCollections
    Write-HostWriter("Done!")
    Write-HostWriter("Starting the data collections...")
    Start-DataCollections
    Write-HostWriter("Done!")
    Write-HostWriter("Reproduce the issue then hit enter once you would like the data collection to stop....")
    $r = Read-Host("Hit Enter once ready....")
    Write-HostWriter("Stopping the data collection now: {0}" -f [System.DateTime]::Now)
    Stop-DataCollectors
    Write-HostWriter("Finished stopping the data collections....")
    sleep 5
    Write-HostWriter("Goodbye!")

}

Main
