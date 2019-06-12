Function Get-AllNicInformation {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ComputerName,
[Parameter(Mandatory=$false)][bool]$Windows2012R2AndAbove = $true,
[Parameter(Mandatory=$false)][string]$ComputerFQDN,
[Parameter(Mandatory=$false)][scriptblock]$CatchActionFunction
)
#Function Version 1.0
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-WmiObjectHandler/Get-WmiObjectHandler.ps1
#>
Write-VerboseWriter("Calling: Get-AllNicInformation")
Write-VerboseWriter("Passed [string]ComputerName: {0} | [bool]Windows2012R2AndAbove: {1} | [string]ComputerFQDN: {2}" -f $ComputerName, $Windows2012R2AndAbove, $ComputerFQDN)

Function Get-NetworkCards {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ComputerName
)
    try 
    {
        $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop 
        $networkCards = Get-NetAdapter -CimSession $cimSession | Where-Object{$_.MediaConnectionState -eq "Connected"} -ErrorAction Stop
        return $networkCards
    }
    catch 
    {
        Write-VerboseWriter("Failed to attempt to get Windows2012R2 or greater advanced NIC settings in Get-NetworkCards. Error {0}." -f $Error[0].Exception)
        throw 
    }
}

Function Get-WmiNetworkCards {
    return (Get-WmiObjectHandler -ComputerName $ComputerName -Class "Win32_NetworkAdapter" -Filter "NetConnectionStatus ='2'" -CatchActionFunction $CatchActionFunction)
}

Function New-NICInformation {
param(
[array]$Adapters,
[bool]$Windows2012R2AndAbove = $true
)
    if($Adapters -eq $null)
    {
        Write-VerboseWriter("Adapters are null in New-NICInformation. Returning a null object.")
        return $null
    }
    [array]$nicObjects = @()
    foreach($adapter in $Adapters)
    {
        if($Windows2012R2AndAbove){$descritpion = $adapter.InterfaceDescription}else {$descritpion = $adapter.Description}
        if($Windows2012R2AndAbove){$driverVersion = $adapter.DriverVersionString}else {$driverVersion = [string]::Empty}
        if($Windows2012R2AndAbove){$driverDate = $adapter.DriverDate}else{$driverDate = [DateTime]::MaxValue}
        if($Windows2012R2AndAbove){$mtuSize = $adapter.MtuSize}else{$mtuSize = 0}
        $nicInformationObj = New-Object PSCustomObject
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "Name" -Value ($adapter.Name)
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "LinkSpeed" -Value ((($adapter.Speed)/1000000).ToString() + " Mbps")
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DriverDate" -Value $driverDate
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "NICObject" -Value $adapter
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "IPv6Enabled" -Value $false
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "Description" -Value $descritpion 
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value $driverVersion
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "MTUSize" -Value $mtuSize
        $nicObjects += $nicInformationObj 
    }
    Write-VerboseWriter("Found {0} active adapters on the computer." -f $nicObjects.Count)
    Write-VerboseWriter("Exiting: Get-AllNicInformation")
    return $nicObjects 
}

if($Windows2012R2AndAbove)
{
    Write-VerboseWriter("Windows OS Version greater than or equal to Windows 2012R2. Going to run Get-NetAdapter")
    try 
    {
        try 
        {
            $networkCards = Get-NetworkCards -ComputerName $ComputerName -ErrorAction Stop 
        }
        catch 
        {
            
            if($CatchActionFunction -ne $null) {& $CatchActionFunction }
            if($ComputerFQDN -ne $null -and $ComputerFQDN -ne [string]::Empty)
            {
                Write-VerboseWriter("Going to attempt FQDN")
                $networkCards = Get-NetworkCards -ComputerName $ComputerFQDN
            }
            else {$bypassCatchAction = $true; Write-VerboseWriter("No FQDN was passed, going to rethrow error."); throw}
            
        }
        return (New-NICInformation -Adapters $networkCards)
    }
    catch 
    {
        Write-VerboseWriter("Failed to get Windows2012R2 or greater advanced NIC settings. Error {0}." -f $Error[0].Exception)
        Write-VerboseWriter("Going to attempt to get WMI Object Win32_NetworkAdapter on this machine instead")
        Write-VerboseWriter("NOTE: This means we aren't able to provide the driver date")
        if(!$bypassCatchAction -and $CatchActionFunction -ne $null) {& $CatchActionFunction }
        $wmiNetCards = Get-WmiNetworkCards -ComputerName $ComputerName 
        return (New-NICInformation -Adapters $wmiNetCards -Windows2012R2AndAbove $false)
    }
}
else 
{
    Write-VerboseWriter("Windows OS Version is less than Windows 2012R2. Going to run Get-WmiObject.")
    $wmiNetCards = Get-WmiNetworkCards -ComputerName $ComputerName
    return (New-NICInformation -Adapters $wmiNetCards -Windows2012R2AndAbove $false)
}

}