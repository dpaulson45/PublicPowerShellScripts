Function Get-CounterSampleToCounterObjectName {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$FullCounterName
)
    
#Function Version 1.0
$counterObject = New-Object -TypeName pscustomobject 

#\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
$endOfServerIndex = $FullCounterName.IndexOf("\",2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
$startOfCounterIndex = $FullCounterName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
$endOfCounterObjectIndex = $FullCounterName.IndexOf("(") 
if($endOfCounterObjectIndex -eq -1){$endOfCounterObjectIndex = $startOfCounterIndex - 1}
if(($FullCounterName.Contains("(")) -and ($FullCounterName.Contains("#")))
{
    $instanceName = ($FullCounterName.Substring($endOfCounterObjectIndex + 1, ($FullCounterName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
}
else 
{
    $instanceName = ($PerformanceCounterSample.InstanceName)
}
$counterObj | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullCounterName
$counterObj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullCounterName.Substring(2,($endOfServerIndex - 2)))
$counterObj | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullCounterName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
$counterObj | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
$counterObj | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullCounterName.Substring($startOfCounterIndex))

return $counterObj

}