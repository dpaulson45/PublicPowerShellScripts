#Dump-StoreWorkerOnPerformanceCounter 
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$DumpFolder = "C:\Data",
[Parameter(Mandatory=$false)][string]$ProcdumpBinary = "C:\Data\Procdump.exe",
[Parameter(Mandatory=$false)][string]$DumpType = "Mini",
[Parameter(Mandatory=$false)][array]$ActiveDatabaseNames,
[Parameter(Mandatory=$false)][int]$PIDRefreshInterval = 600,
[Parameter(Mandatory=$false)][int]$SleepMilliseconds = 100,
[Parameter(Mandatory=$false)][bool]$ScriptDebug = $true
)

$scriptVersion = 0.2

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

#Function Version 1.3
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
            $counters += $mainWatchCounter -f $db 
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

    $perfObj = New-PerformanceCounterMonitorThresholdObject -Perfcounters $hash -MaxSamples 2
    return $perfObj
}

Function Set-StoreWorkerPIDCache {

    $Script:PIDCache = @{}
    Write-Host("[{0}]: Updating the StoreWorker PID Cache" -f [System.DateTime]::Now)
    foreach($db in $ActiveDatabaseNames)
    {
        $counter = "\MSExchangeIS store({0})\Process ID" -f $db 
        $workerPid = (Get-Counter -Counter $counter).CounterSamples.CookedValue
        $Script:PIDCache.Add($db, $workerPid)
    }

    $Script:UpdatePIDCache = ([datetime]::Now).AddSeconds($PIDRefreshInterval)
    Write-Host("[{0}]: Finished updating the cache, next update time: {1}" -f [System.DateTime]::Now, $Script:UpdatePIDCache)
}

Function Main {
    
    $perfMonitor = Get-PerformanceCountersMonitorThresholdObject
    
    $dpType = [string]::Empty
    Switch($DumpType)
    {
        "Mini" {$dpType = [string]::Empty; break;}
        "MP" {$dpType = "-mp"; break}
        "MA" {$dpType = "-ma"; break}
    }
    
    $issueCount = 0
    Set-StoreWorkerPIDCache 
    while($issueCount -lt 10)
    {
        do{
            if($Script:UpdatePIDCache -lt [DateTime]::Now)
            {
                Set-StoreWorkerPIDCache
            }
            $monitorStatus = $perfMonitor.GetMonitorResults()
        }while($monitorStatus -eq [PerfCounterMonitor.StatusCode]::Passed)

        $thresholdMetCounter = $perfMonitor.ThresholdMetObjectDetails.Counter
        Write-Host("[{0}]: threshold met counter: {1}" -f [System.DateTime]::Now, $thresholdMetCounter)
        $counterObject = Get-CounterFullNameToCounterObjectName -FullCounterName $thresholdMetCounter
        $instance = $counterObject.InstanceName
        Write-Host("[{0}]: Instance name: {1}" -f [System.DateTime]::Now, $instance)
        $workerPid = $Script:PIDCache[$instance]
        Write-Host("[{0}]: PID: {1}" -f [System.DateTime]::Now, $workerPid)
        & $ProcdumpBinary $dpType $workerPid $DumpFolder -accepteula 
        Write-Host("[{0}]: Finished dumpping the process" -f [System.DateTime]::Now)
        $issueCount++
        Set-StoreWorkerPIDCache
        sleep 2
    }
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

$mainWatchCounter = "\MSExchangeIS store({0})\rpc operations/sec"
Write-Host $display
Main