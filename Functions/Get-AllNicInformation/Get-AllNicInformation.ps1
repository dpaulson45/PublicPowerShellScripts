Function Get-AllNicInformation {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$ComputerName,
[Parameter(Mandatory=$false)][string]$ComputerFQDN,
[Parameter(Mandatory=$false)][scriptblock]$CatchActionFunction
)
#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-WmiObjectHandler/Get-WmiObjectHandler.ps1
#>
Write-VerboseWriter("Calling: Get-AllNicInformation")
Write-VerboseWriter("Passed [string]ComputerName: {0} | [string]ComputerFQDN: {1}" -f $ComputerName, $ComputerFQDN)

Function Get-NetworkConfiguration {
[CmdletBinding()]
param(
[string]$ComputerName
)
    try
    {
        $currentErrors = $Error.Count
        $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
        $networkIpConfiguration = Get-NetIPConfiguration -CimSession $CimSession -ErrorAction Stop

        if ($CatchActionFunction -ne $null)
        {
            $index = 0
            while ($index -lt ($Error.Count - $currentErrors))
            {
                & $CatchActionFunction $Error[$index]
                $index++
            }
        }

        return $networkIpConfiguration
    }
    catch
    {
        Write-VerboseWriter("Failed to run Get-NetIPConfiguration. Error {0}." -f $Error[0].Exception)

        if ($CatchActionFunction -ne $null)
        {
            & $CatchActionFunction
        }

        throw
    }
}

Function New-NICInformation {
param(
[array]$NetworkConfigurations,
[bool]$WmiObject
)
    if($NetworkConfigurations -eq $null)
    {
        Write-VerboseWriter("NetworkConfigurations are null in New-NICInformation. Returning a null object.")
        return $null
    }

    Function New-IpvAddresses {
        
        $obj = New-Object PSCustomObject
        $obj | Add-Member -MemberType NoteProperty -Name "Address" -Value ([string]::Empty)
        $obj | Add-Member -MemberType NoteProperty -Name "Subnet" -Value ([string]::Empty)
        $obj | Add-Member -MemberType NoteProperty -Name "DefaultGateway" -Value ([string]::Empty)

        return $obj
    }

    [array]$nicObjects = @()
    foreach($networkConfig in $NetworkConfigurations)
    {
        if (!$WmiObject)
        {
            $adapter = $networkConfig.NetAdapter

            try
            {
                $dnsClient = $adapter | Get-DnsClient
            }
            catch
            {
                if ($CatchActionFunction -ne $null)
                {
                    & $CatchActionFunction
                }
            }
        }
        else
        {
            $adapter = $networkConfig
        }

        $nicInformationObj = New-Object PSCustomObject
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "WmiObject" -Value $WmiObject
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "Name" -Value ($adapter.Name)
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "LinkSpeed" -Value ((($adapter.Speed)/1000000).ToString() + " Mbps")
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DriverDate" -Value [DateTime]::MaxValue
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "NICObject" -Value $networkConfig
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "IPv6Enabled" -Value $false
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "Description" -Value $adapter.Description
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value [string]::Empty
        $nicInformationObj | Add-Member -MemberType NoteProperty -Name "MTUSize" -Value 0

        if (!$WmiObject)
        {
            $nicInformationObj.MTUSize = $adapter.MtuSize
            $nicInformationObj.DriverDate = $adapter.DriverDate
            $nicInformationObj.DriverVersion = $adapter.DriverVersionString
            $nicInformationObj.Description = $adapter.InterfaceDescription
            
            $ipv4Address = @()
            for ($i = 0; $i -lt $networkConfig.IPv4Address.Count; $i++)
            {
                $obj = New-IpvAddresses
                
                if ($networkConfig.IPv4Address -ne $null -and
                    $i -lt $networkConfig.IPv4Address.Count)
                {
                    $obj.Address = $networkConfig.IPv4Address[$i].IPAddress
                    $obj.Subnet = $networkConfig.IPv4Address[$i].PrefixLength
                }

                if ($networkConfig.IPv4DefaultGateway -ne $null -and
                    $i -lt $networkConfig.IPv4DefaultGateway.Count)
                {
                    $obj.DefaultGateway = $networkConfig.IPv4DefaultGateway[$i].NextHop
                }

                $ipv4Address += $obj
            }

            $ipv6Address = @()
            for ($i = 0; $i -lt $networkConfig.IPv6Address.Count; $i++)
            {
                $obj = New-IpvAddresses
                
                if ($networkConfig.IPv6Address -ne $null -and
                    $i -lt $networkConfig.IPv6Address.Count)
                {
                    $obj.Address = $networkConfig.IPv6Address[$i].IPAddress
                    $obj.Subnet = $networkConfig.IPv6Address[$i].PrefixLength
                }

                if ($networkConfig.IPv6DefaultGateway -ne $null -and
                    $i -lt $networkConfig.IPv6DefaultGateway.Count)
                {
                    $obj.DefaultGateway = $networkConfig.IPv6DefaultGateway[$i].NextHop
                }

                $ipv6Address += $obj
            }
            
            $nicInformationObj | Add-Member -MemberType NoteProperty -Name "IPv4Addresses" -Value $ipv4Address
            $nicInformationObj | Add-Member -MemberType NoteProperty -Name "Ipv6Addresses" -Value $ipv6Address 
            $nicInformationObj | Add-Member -MemberType NoteProperty -Name "RegisteredInDns" -Value $dnsClient.RegisterThisConnectionsAddress
            $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DnsServer" -Value $networkConfig.DNSServer.ServerAddresses
            $nicInformationObj | Add-Member -MemberType NoteProperty -Name "DnsClientObject" -Value $dnsClient
        }

        $nicObjects += $nicInformationObj 
    }

    Write-VerboseWriter("Found {0} active adapters on the computer." -f $nicObjects.Count)
    Write-VerboseWriter("Exiting: Get-AllNicInformation")
    return $nicObjects 
}

try
{
    try
    {
        $networkConfiguration = Get-NetworkConfiguration -ComputerName $ComputerName
    }
    catch
    {
        if ($CatchActionFunction -ne $null)
        {
            & $CatchActionFunction
        }

        if ($ComputerFQDN -ne [string]::Empty -and
            $ComputerName -ne $null)
        {
            $networkConfiguration = Get-NetworkConfiguration -ComputerName $ComputerFQDN
        }
        else
        {
            $bypassCatchActions = $true
            Write-VerboseWriter("No FQDN was passed, going to rethrow error.")
            throw
        }
    }

    return (New-NICInformation -NetworkConfigurations $networkConfiguration)
}
catch
{
    if (!$bypassCatchActions -and
        $CatchActionFunction -ne $null)
    {
        & $CatchActionFunction
    }

    $wmiNetworkCards = Get-WmiObjectHandler -ComputerName $ComputerName -Class "Win32_NetworkAdapter" -Filter "NetConnectionStatus ='2'" -CatchActionFunction $CatchActionFunction
    return (New-NICInformation -NetworkConfigurations $wmiNetworkCards -WmiObject $true)
}

}