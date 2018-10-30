[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Directory,
[Parameter(Mandatory=$false)][Int64]$MaxSample = [Int64]::MaxValue, 
[Parameter(Mandatory=$false)][datetime]$StartTime = [datetime]::MinValue, 
[Parameter(Mandatory=$false)][datetime]$EndTime = [datetime]::MaxValue,
[Parameter(Mandatory=$false)][array]$Counters
)


Add-Type @"
using System; 
using System.Collections.Generic;
using System.Linq;

namespace PerformanceCounters
{
    public class CounterAccuracy
    {
        public double Percentage; 
        public int SumDataPoints;
        public int EstimateDataPoints; 

        public CounterAccuracy()
        {
            this.Percentage = 0; 
            this.SumDataPoints = 0; 
            this.EstimateDataPoints = 0; 
        }
    }

    public class PerformanceCounterName
    {
        public string FullName; 
        public string ServerName; 
        public string ObjectName; 
        public string InstanceName; 
        public string CounterName; 
    }

    public class CounterData : PerformanceCounterName
    {
        public CounterAccuracy Accurarcy; 
        public object[] AllData; 
        public IEnumerable<object> GetData { get {return AllData.Skip(1); } }
        public object FirstSample {get {return GetData.First(); } }
        public object LastSample {get {return GetData.Last(); } }

        public CounterData()
        {
            this.Accurarcy = new CounterAccuracy();
        }
    }
}


"@


Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($VerboseFunctionCaller -eq $null)
        {
            Write-Verbose $WriteString
        }
        else 
        {
            &$VerboseFunctionCaller $WriteString
        }
    }
    
    Function Write-HostWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($HostFunctionCaller -eq $null)
        {
            Write-Host $WriteString
        }
        else
        {
            &$HostFunctionCaller $WriteString    
        }
    }
 
################################################################
#
# Template Functions 
#
################################################################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Import-PerformanceCounters/Import-PerformanceCounters.ps1
Function Import-PerformanceCounters {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Directory,
[Parameter(Mandatory=$false)][Int64]$MaxSample = [Int64]::MaxValue, 
[Parameter(Mandatory=$false)][datetime]$StartTime = [datetime]::MinValue, 
[Parameter(Mandatory=$false)][datetime]$EndTime = [datetime]::MaxValue,
[Parameter(Mandatory=$false)][array]$Counters
)

<#
    When passing something like \\*\Process(*)\* we see a dramatic decrease in performance of reading the file. In a 1 GB file we see a decrease of performance by a few minutes vs providing all the values for the counters in Process
    For example: "\\*\Process(*)\% Privileged Time","\\*\Process(*)\% Processor Time","\\*\Process(*)\% User Time","\\*\Process(*)\Creating Process ID",..... so on
#>

#Function Version 1.1
Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        #Always want to add [{0}]: date time now to the start of the string 
        $WriteString = "[{0}]: {1}" -f [datetime]::Now, $WriteString
        if($VerboseFunctionCaller -eq $null)
        {
            Write-Verbose $WriteString
        }
        else 
        {
            &$VerboseFunctionCaller $WriteString
        }
    }
    
#############################
#
# Import-PerformanceCounters -- Template Functions 
#
#############################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
Function Get-CounterSampleToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)

#Function Version 1.1

$counterObj = New-Object -TypeName pscustomobject
$FullName = $PerformanceCounterSample.Path 
#\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
$endOfServerIndex = $FullName.IndexOf("\",2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
$startOfCounterIndex = $FullName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
$endOfCounterObjectIndex = $FullName.IndexOf("(") 
if($endOfCounterObjectIndex -eq -1){$endOfCounterObjectIndex = $startOfCounterIndex - 1}
if(($FullName.Contains("(")) -and ($FullName.Contains("#")))
{
    $instanceName = ($FullName.Substring($endOfCounterObjectIndex + 1, ($FullName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
}
else 
{
    $instanceName = ($PerformanceCounterSample.InstanceName)
}
$counterObj | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullName
$counterObj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullName.Substring(2,($endOfServerIndex - 2)))
$counterObj | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObj | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
$counterObj | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullName.Substring($startOfCounterIndex))

return $counterObj
}
# End Function Get-CounterSampleToCounterObjectName





#############################
#
# End Import-PerformanceCounters -- Template Functions 
#
#############################

Function Get-FastCounterNames {
param(
[Parameter(Mandatory=$true)][array]$FilePaths 
)
    Write-VerboseWriter("Getting the Counter Names vs using wild card as this has better performance")
    [System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $myParmas = @{
        Path = $FilePaths
        StartTime = $StartTime
        EndTime = $EndTime
        MaxSample = 2
        ErrorAction = "SilentlyContinue"
        Verbose = $false 
        Counter = $Counters
    }
    
    $measureImport = Measure-Command {$results = (Import-Counter @myParmas).CounterSamples}
    Write-VerboseWriter("Took {0} seconds to import" -f $measureImport.TotalSeconds)

    $measureGroup = Measure-Command { $groupResults = $results | Group-Object Path }
    Write-VerboseWriter("Took {0} seconds to group the results" -f $measureGroup.TotalSeconds)

    $masterCounterList = @() 
    foreach($counterGroup in $groupResults)
    {
        $inList = $false
        $counterName = $counterGroup.Name 
        foreach($counterCheck in $masterCounterList)
        {
            if($counterName -like $counterCheck)
            {
                $inList = $true 
                break; 
            }
        }
        if($inList)
        {
            continue 
        }
        $counterNameObj = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $counterGroup.Group[0]
        if([string]::IsNullOrEmpty($counterNameObj.InstanceName))
        {
            $addCounter = "\\*\{0}\{1}"
        }
        else 
        {
            $addCounter = "\\*\{0}(*)\{1}"    
        }
        $addCounter = $addCounter -f $counterNameObj.ObjectName, $counterNameObj.CounterName
        $masterCounterList += $addCounter
    }
    $stopWatch.Stop()
    Write-VerboseWriter("Finished getting the counter list in {0} seconds" -f $stopWatch.Elapsed.TotalSeconds)
    return $masterCounterList
}




if(-not(Test-Path $Directory))
{
    $displayError = "Failed to provide valid Directory. '{0}'" -f $Directory
    throw [System.Management.Automation.ParameterBindingException] $displayError
}
if($StartTime -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid StartTime"
}
if($EndTime -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EndTime"
}
if($MaxSample -eq $null)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxSample"
}
if(($files = Get-ChildItem $Directory | ?{$_.Extension -eq ".blg"}) -eq $null)
{
    throw "No files in the directory"
}

$filePaths = @()

foreach($file in $files)
{
    $filePaths += $file.VersionInfo.FileName
}

$params = @{
    Path = $filePaths
    StartTime = $StartTime
    EndTime = $EndTime
    MaxSample = $MaxSample
    ErrorAction = "SilentlyContinue"
    Verbose = $false 
}

if($Counters -ne $null -and $Counters.count -gt 0)
{
    $fastCounters = Get-FastCounterNames -FilePaths ($filePaths[0])
    $params.Add("Counter", $fastCounters)
}

$totalSize = 0
Write-VerboseWriter("Importing files from batch list")
foreach($file in $filePaths)
{
    Write-VerboseWriter("File Size {0}MB. File Name: {1}." -f ($size = (Get-Item $file).Length / 1MB), $file )
    $totalSize += $size
}
[System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$importCounters = (Import-Counter @params).CounterSamples
Write-VerboseWriter("Took {0} seconds to import this batch size of {1}MB for {2} datapoints." -f $stopWatch.Elapsed.TotalSeconds, $totalSize, $importCounters.count)
return $importCounters

}
# End Function Import-PerformanceCounters




# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
Function Get-CounterSampleToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)

#Function Version 1.1

$counterObj = New-Object -TypeName pscustomobject
$FullName = $PerformanceCounterSample.Path 
#\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
$endOfServerIndex = $FullName.IndexOf("\",2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
$startOfCounterIndex = $FullName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
$endOfCounterObjectIndex = $FullName.IndexOf("(") 
if($endOfCounterObjectIndex -eq -1){$endOfCounterObjectIndex = $startOfCounterIndex - 1}
if(($FullName.Contains("(")) -and ($FullName.Contains("#")))
{
    $instanceName = ($FullName.Substring($endOfCounterObjectIndex + 1, ($FullName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
}
else 
{
    $instanceName = ($PerformanceCounterSample.InstanceName)
}
$counterObj | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullName
$counterObj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullName.Substring(2,($endOfServerIndex - 2)))
$counterObj | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObj | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
$counterObj | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullName.Substring($startOfCounterIndex))

return $counterObj
}
# End Function Get-CounterSampleToCounterObjectName





################################################################
#
# End Template Functions 
#
################################################################

Function Get-CounterDataObject {
param(
[Parameter(Mandatory=$true)][object]$PerformanceCounterSample
)
    $counterDataObj = New-Object PerformanceCounters.CounterData
    $counterNameObj = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $PerformanceCounterSample
    $counterDataObj.FullName = $counterNameObj.FullName
    $counterDataObj.ServerName = $counterNameObj.ServerName
    $counterDataObj.ObjectName = $counterNameObj.ObjectName
    $counterDataObj.InstanceName = $counterNameObj.InstanceName
    $counterDataObj.CounterName = $counterNameObj.CounterName
    return $counterDataObj
}

[System.Diagnostics.Stopwatch]$stopWatchTotal = [System.Diagnostics.Stopwatch]::StartNew()
$importCounters = Import-PerformanceCounters -Directory $Directory -MaxSample $MaxSample -StartTime $StartTime -EndTime $EndTime -Counters $Counters 
$measureGroupTime = Measure-Command { $groupData = $importCounters | Group-Object Path }
Write-VerboseWriter("[{0}]: Took {1} seconds to group the path data" -f [datetime]::Now, $measureGroupTime.TotalSeconds)
[System.Diagnostics.Stopwatch]$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$hashtable = @{}
foreach($counterData in $groupData)
{
    $counterObj =  Get-CounterDataObject -PerformanceCounterSample $counterData.Group[0]
    $counterObj.AllData = $counterData.Group 
    $hashtable.Add($counterObj.FullName, $counterObj)
}
Write-VerboseWriter("[{0}]: Finished building objects off the data. Completed in {1} seconds" -f [datetime]::Now, $stopWatch.Elapsed.TotalSeconds)
Write-VerboseWriter("[{0}]: Total time taken {1} seconds" -f [datetime]::Now, $stopWatchTotal.Elapsed.TotalSeconds)
return $hashtable
