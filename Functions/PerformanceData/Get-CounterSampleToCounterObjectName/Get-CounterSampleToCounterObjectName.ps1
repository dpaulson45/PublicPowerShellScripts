Function Get-CounterSampleToCounterObjectName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$PerformanceCounterSample
    )

    $counterObj = New-Object -TypeName PSCustomObject
    $FullName = $PerformanceCounterSample.Path
    #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
    $endOfServerIndex = $FullName.IndexOf("\", 2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
    $startOfCounterIndex = $FullName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
    $endOfCounterObjectIndex = $FullName.IndexOf("(")
    if ($endOfCounterObjectIndex -eq -1) { $endOfCounterObjectIndex = $startOfCounterIndex - 1 }
    if (($FullName.Contains("(")) -and ($FullName.Contains("#"))) {
        $instanceName = ($FullName.Substring($endOfCounterObjectIndex + 1, ($FullName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
    } else {
        $instanceName = ($PerformanceCounterSample.InstanceName)
    }
    $counterObj | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullName
    $counterObj | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullName.Substring(2, ($endOfServerIndex - 2)))
    $counterObj | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
    $counterObj | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
    $counterObj | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullName.Substring($startOfCounterIndex))

    return $counterObj
}