Function Get-CounterFullNameToCounterObjectName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FullCounterName
    )

    $counterObject = New-Object -TypeName PSCustomObject

    #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\avg. disk sec/read
    $endOfServerIndex = $FullCounterName.IndexOf("\", 2) #\\adt-e2k13aio1 <> \logicaldisk(harddiskvolume1)\avg. disk sec/read
    $startOfCounterIndex = $FullCounterName.LastIndexOf("\") + 1 #\\adt-e2k13aio1\logicaldisk(harddiskvolume1)\ <> avg. disk sec/read
    $endOfCounterObjectIndex = $FullCounterName.IndexOf("(")
    if ($endOfCounterObjectIndex -eq -1) { $endOfCounterObjectIndex = $startOfCounterIndex - 1 }
    if (($FullCounterName.Contains("("))) {
        $instanceName = ($FullCounterName.Substring($endOfCounterObjectIndex + 1, ($FullCounterName.IndexOf(")") - $endOfCounterObjectIndex - 1)))
    }
    $counterObject | Add-Member -MemberType NoteProperty -Name "FullName" -Value $FullCounterName
    $counterObject | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($FullCounterName.Substring(2, ($endOfServerIndex - 2)))
    $counterObject | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value ($FullCounterName.Substring($endOfServerIndex + 1, $endOfCounterObjectIndex - $endOfServerIndex - 1))
    $counterObject | Add-Member -MemberType NoteProperty -Name "InstanceName" -Value $instanceName
    $counterObject | Add-Member -MemberType NoteProperty -Name "CounterName" -Value ($FullCounterName.Substring($startOfCounterIndex))

    return $counterObject
}