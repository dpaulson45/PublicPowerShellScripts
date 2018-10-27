<#
Name: Start-MonitorOnPerformanceCounterThreshold.ps1
Author: David Paulson

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#>
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$SMTPSender,
[Parameter(Mandatory=$false)][array]$SMTPRecipients,
[Parameter(Mandatory=$false)][string]$SMTPServerNameOrIPAddress = $ENV:COMPUTERNAME,
[Parameter(Mandatory=$false)][PSCredential]$MailCreds,
[Parameter(Mandatory=$false)][string]$SaveAllDataPath = ".",
[Parameter(Mandatory=$false)][int]$LoopLimit = 20,
[Parameter(Mandatory=$false)][array]$Counters = @("\logicaldisk(*)\avg. disk sec/write","\logicaldisk(*)\avg. disk sec/read"),
[Parameter(Mandatory=$false)][double]$AverageThreshold = 0.030,
[Parameter(Mandatory=$false)][double]$MaxSpikeThreshold = 0.400,
[Parameter(Mandatory=$false)][switch]$StopDataCollectors
)

$scriptVersion = 0.1

$display = @"

    Monitor on Performance Counter Threshold v{0}

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    This script is currently designed to monitor the local server to see if it goes above a particular threshold and notify the admin via email. 
    With this monitoring, it will also stop particular data collection if need be. 

    Data Collection Enabled Types
    -Experfwiz 
    -Storport
"@ -f $scriptVersion



#############################
#
# Template Functions 
#
#############################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-StorportLogmanObject/New-StorportLogmanObject.ps1
Function New-StorportLogmanObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogmanName = "storport",
[Parameter(Mandatory=$false)][string]$SaveName,
[Parameter(Mandatory=$false)][int]$EtlFileSize = 4096,
[Parameter(Mandatory=$false)][string]$SavePath = "C:\Traces",
[Parameter(Mandatory=$false)][string]$Provider = "Microsoft-Windows-StorPort",
[Parameter(Mandatory=$false)][string]$AppendVersioningToFile = "mmddhhmm",
[Parameter(Mandatory=$false)][array]$ServerList,
[Parameter(Mandatory=$false)][string]$KeywordsAny = "0xffffffffffffffff",
[Parameter(Mandatory=$false)][string]$Level = "0xff",
[Parameter(Mandatory=$false)][int]$MinimumBuffer = 16, #Note this appears to have a max min value of 20 on newer systems but still works 
[Parameter(Mandatory=$false)][int]$MaximumBuffer = 16, 
[Parameter(Mandatory=$false)][int]$BufferSizeKB = 1024, #default is actually 8KB 
[Parameter(Mandatory=$false)][string]$LogFormat = "bincirc"
)

#Following this blog: https://blogs.technet.microsoft.com/askcore/2013/04/25/tracing-with-storport-in-windows-2012-and-windows-8-with-kb2819476-hotfix/
#Function Version 1.0
if([string]::IsNullOrEmpty($LogmanName.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName" 
}
if($EtlFileSize -lt 100 -or $EtlFileSize -gt 10000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 10000"
}
if([string]::IsNullOrEmpty($SavePath.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SavePath" 
}
if([string]::IsNullOrEmpty($Provider.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider" 
}
if([string]::IsNullOrEmpty($AppendVersioningToFile.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
}
if($ServerList -eq $null -or $ServerList.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ServerList"
}
if([string]::IsNullOrEmpty($KeywordsAny.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid KeywordsAny" 
}
if([string]::IsNullOrEmpty($Level.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Level" 
}
if($MinimumBuffer -lt 10 -or $MinimumBuffer -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MinimumBuffer. Use a value between 10 and 1000"
}
if($MaximumBuffer -lt 10 -or $MaximumBuffer -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaximumBuffer. Use a value between 10 and 1000"
}
if($BufferSizeKB -lt 8 -or $BufferSizeKB -gt 4096)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BufferSizeKB. Use a value between 8 and 4096"
}
if([string]::IsNullOrEmpty($LogFormat.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat" 
}
if([string]::IsNullOrEmpty($SaveName.Trim()))
{
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
    foreach($server in $ServerList)
    {
        $statusObject = New-Object pscustomobject
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartStatusCode" -Value ([StorportLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedStatusCode" -Value ([StorportLogman.StatusCode]::None)

        $hasher.Add($server,$statusObject)
    }
    return $hasher
}

$logmanObject = New-Object pscustomobject 

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
    $appendVersion = $this.AppendVersion
    $provider = $this.Provider
    $keywordsAny = $this.KeywordsAny
    $level = $this.Level
    $minimumBuffer = $this.MinimumBuffer
    $maximumBuffer = $this.MaximumBuffer
    $bufferSizeKB = $this.BufferSizeKB
    $logFormat = $this.LogFormat
    $failedCount = 0 
    foreach($server in $servers)
    {
        $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
        [array]$results = logman create trace $logman -o $fullFileName -p $provider $keywordsAny $level -nb $minimumBuffer $maximumBuffer -bs $bufferSizeKB -f $logFormat -max $maxSize -s $server -ets 
        $this.ServersStatus[$server].CreateStartResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Failed
            $failedCount++
        }
    }
    switch($failedCount)
    {
        0{return [StorportLogman.StatusCode]::Success}
        {(-eq $servers.Count)}{return [StorportLogman.StatusCode]::Failed}
        default {return [StorportLogman.StatusCode]::SingleServerFailure}
    }

}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    
    $servers = $this.Servers 
    $logman = $this.TraceName
    $failureCount = 0 
    foreach($server in $servers)
    {
        [array]$results = logman stop $logman -s $server -ets 
        $this.ServersStatus[$server].StoppedResults = $results
        if(($results[-1].Trim()) -eq"The command completed successfully.")
        {
            $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0{return [StorportLogman.StatusCode]::Success}
        {($failureCount -eq $servers.Count)}{return [StorportLogman.StatusCode]::Failed}
        default {return [StorportLogman.StatusCode]::SingleServerFailure}
    }
}

return $logmanObject
}
# End Function New-StorportLogmanObject




# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-PerformanceCounterMonitorThresholdObject/New-PerformanceCounterMonitorThresholdObject.ps1
Function New-PerformanceCounterMonitorThresholdObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][hashtable]$Perfcounters,
[Parameter(Mandatory=$false)][int]$SampleInterval = 1,
[Parameter(Mandatory=$false)][int]$MaxSamples = 10,
[Parameter(Mandatory=$false)][int]$SleepTime = 0,
[Parameter(Mandatory=$false)][int]$UpdateEveryXMinutes = 5,
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

#Function Version 1.0
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

$perfMonitorObject = New-Object pscustomobject 

$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "PerformanceCounters" -Value $Perfcounters
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SampleInterval" -Value $SampleInterval
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "MaxSamples" -Value $MaxSamples
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "SleepTime" -Value $SleepTime
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "Counters" -Value (Get-Counters)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "NextUpdateTime" -Value ([DateTime]::Now)
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "UpdateMinuteInterval" -Value $UpdateEveryXMinutes
$perfMonitorObject | Add-Member -MemberType NoteProperty -Name "ThresholdMetDetails" -Value ([string]::Empty)
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
        $Global:MinMaxAvgResults = $minMaxAvgResults
        if($counterPassedObj.ThresholdType -eq "GreaterThan")
        {
            if($minMaxAvgResults.Max -ge $counterPassedObj.MaxSpikeThreshold)
            {
                $details = "Met max spike threshold. Current max spike is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Max, $counterPassedObj.MaxSpikeThreshold, $counterName
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -ge $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is above the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdMet = $true 
            }
        }
        elseif($counterPassedObj.ThresholdType -eq "LessThan")
        {
            if($minMaxAvgResults.Min -le $counterPassedObj.MinDipThreshold)
            {
                $details = "Met min dip threshold. Current min dip is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Min, $counterPassedObj.MinDipThreshold, $counterName
                $thresholdMet = $true 
            }
            if($minMaxAvgResults.Avg -le $counterPassedObj.AverageThreshold)
            {
                $details = "Met average threshold. Current average is '{0}' which is below the threshold '{1}'. Counter: '{2}'" -f $minMaxAvgResults.Avg, $counterPassedObj.AverageThreshold, $counterName
                $thresholdMet
            }   
        }
        if($thresholdMet)
        {
            $this.ThresholdMetDetails = $details
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




# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-MailMessageObject/New-MailMessageObject.ps1
Function New-MailMessageObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$SMTPSender,
[Parameter(Mandatory=$true)][array]$SMTPRecipients,
[Parameter(Mandatory=$true)][string]$SMTPServerNameOrIPAddress,
[Parameter(Mandatory=$true)][string]$MessageSubject,
[Parameter(Mandatory=$false)][string]$MessageBody,
[Parameter(Mandatory=$false)][PSCredential]$Credentials,
[Parameter(Mandatory=$false)][int]$Port = 25,
[Parameter(Mandatory=$false)][string]$CustomTestMessageSubject = "Script Mail Message Object Test",
[Parameter(Mandatory=$false)][string]$CustomTestMessageBody = "Test Worked!"
)
#Function Version 1.0
if([string]::IsNullOrWhiteSpace($CustomTestMessageSubject))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageSubject"
}
if([string]::IsNullOrWhiteSpace($CustomTestMessageBody))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageBody"
}

$params = @{
    To = $SMTPRecipients
    From = $SMTPSender
    SmtpServer = $SMTPServerNameOrIPAddress
    Port = $Port
    Subject = $CustomTestMessageSubject
    Body = $CustomTestMessageBody
}
[bool]$passedCreds = $false 
if([pscredential]::Empty -ne $Credentials -and $Credentials -ne $null)
{
    $passedCreds = $true 
    $params.Add("Credential", $Credentials)
}

try 
{
    Send-MailMessage @params -ErrorAction Stop
}
catch 
{
    throw
}

#Passed sending the message, going to build the object 
$params["Subject"] = $MessageSubject
if([string]::IsNullOrWhiteSpace($MessageBody))
{
    $params.Remove("Body")
}
else 
{
    $params["Body"] = $MessageBody
}


$mailObject = New-Object -TypeName pscustomobject 
$mailObject | Add-Member -MemberType NoteProperty -Name "Parameters" -Value $params
$mailObject | Add-Member -MemberType NoteProperty -Name "Exception" -Value ([string]::Empty)
$mailObject | Add-Member -MemberType NoteProperty -Name "Success" -Value $true 

$mailObject | Add-Member -MemberType ScriptMethod -Name "SendMail" -Value {

    $params = $this.Parameters 
    try 
    {
        Send-MailMessage @params 
    }
    catch 
    {
        $this.Success = $false 
        $this.Exception = $Error[0].Exception
    }
    
} 

$mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageBody" -Value {
    param(
    [string]$Body
    )
    [hashtable]$params = $this.Parameters
    $bodyNullEmpty = $false 
    if([string]::IsNullOrWhiteSpace($Body))
    {
        $bodyNullEmpty = $true  
    }
    if($params.ContainsKey("Body"))
    {
        if($bodyNullEmpty)
        {
            $params.Remove("Body") 
        }
        else 
        {
            $params["Body"] = $Body
        }
    }
    else 
    {
        if($bodyNullEmpty)
        {
            return 
        }
        $params.Add("Body", $Body)     
    }
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageSubject" -Value {
    param(
    [string]$MessageSubject
    )
    if([string]::IsNullOrWhiteSpace($MessageSubject))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide MessageSubject"
    }
    $params = $this.Parameters 
    $params["Subject"] = $MessageSubject
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "GetMessageSuccess" -Value {
    return $this.Success 
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "GetExceptionReason" -Value {
    return $this.Exception
}

return $mailObject 
}
# End Function New-MailMessageObject





################################
#
# Script Functions 
#
################################


Function Get-StorportLogmanObject {

    $servers = @($ENV:COMPUTERNAME)
    $saveName = "Storport_Script_Monitor_{0}" -f (([DateTime]::Now).ToString("yyyyMMddHHmmss"))
    $obj = New-StorportLogmanObject -SaveName $saveName -SavePath $SaveAllDataPath -ServerList $servers
    return $obj
}

Function Get-PerformanceCountersMonitorThresholdObject {

    Function Get-PerfDataThresholdsObj 
    {
        $obj = New-Object pscustomobject 
        $obj | Add-Member -MemberType NoteProperty -Name "AverageThreshold" -Value $AverageThreshold
        $obj | Add-Member -MemberType NoteProperty -Name "MaxSpikeThreshold" -Value $MaxSpikeThreshold
        $obj | Add-Member -MemberType NoteProperty -Name "ThresholdType" -Value "GreaterThan"
        return $obj
    }
    try 
    {
        $counterSamples = (Get-Counter -Counter $Counters -ErrorAction Stop).CounterSamples
    }
    catch 
    {
        $displayError = ("Failed to get counter for this computer. Error: '{0}'" -f ($Error[0].Exception))
        throw $displayError
    }

    $hash = @{}
    $paths = ($counterSamples | group path).Name
    foreach($path in $paths)
    {
        $hash.Add($path, (Get-PerfDataThresholdsObj))
    }

    $perfObj = New-PerformanceCounterMonitorThresholdObject -Perfcounters $hash -SleepTime 1
    return $perfObj
}

Function Main {
    $params = @{
        SMTPSender = $SMTPSender
        SMTPRecipients = $SMTPRecipients
        SMTPServerNameOrIPAddress = $SMTPServerNameOrIPAddress
        MessageSubject = "Monitor Disks Script"
        CustomTestMessageSubject = "Monitor Disk Script Test Of Send-Message"
    }
    if($MailCreds -ne $null)
    {
        $params.Add("Credentials",$MailCreds)
    }
    $mailObject = New-MailMessageObject @params
    $perfMonitor = Get-PerformanceCountersMonitorThresholdObject

    $monitorStatus = [PerfCounterMonitor.StatusCode]::Passed

    $issueCount = 0 
    while($issueCount -lt $LoopLimit)
    {
        $storportObject = Get-StorportLogmanObject
        $storportObject.CreateAndStartTrace()
        do{
            $monitorStatus = $perfMonitor.GetMonitorResults()
        }while($monitorStatus -ne [PerfCounterMonitor.StatusCode]::ThresholdMet)

        $storportObject.StopLogman()
        #TODO would be nice to include files that are related to this issue that we are going to stop
        $mailObject.UpdateMessageSubject("Monitor Disks Script - Threshold Met")
        $messageBody = "Server {0} has reached the threshold. Details: '{1}'" -f $ENV:COMPUTERNAME, $perfMonitor.ThresholdMetDetails
        $mailObject.UpdateMessageBody($messageBody)
        $mailObject.SendMail()
        $issueCount++
    }

    $mailObject.UpdateMessageSubject("Monitor Disks Script - Script Stopped Limit Reached")
    $mailObject.UpdateMessageBody(("Limit of {0} was reached on server {1}. If you want to continue getting data, please restart the script." -f $LoopLimit,$ENV:COMPUTERNAME))
    $mailObject.SendMail()
    
}

######### Stop Data Collectors ##############
if($StopDataCollectors)
{   
    $storportObject = Get-StorportLogmanObject 
    $storportObject.StopLogman()

    exit 
}

####### Check for Parameter Issues ##########
$failedString = "Failed to provide valid {0}."
if([string]::IsNullOrEmpty($SMTPSender))
{
    throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPSender")
}
if([string]::IsNullOrEmpty($SMTPRecipients))
{
    throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPRecipients")
}
if([string]::IsNullOrEmpty($SMTPServerNameOrIPAddress))
{
    throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SMTPServerNameOrIPAddress")
}
if(-not(Test-Path -Path $SaveAllDataPath))
{
    throw [System.Management.Automation.ParameterBindingException] ($failedString -f "SaveAllDataPath. Please provide a valid path.")
}

################################

Main 
