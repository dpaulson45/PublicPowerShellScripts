Function Get-ExchangeClientProtocolMappings {

    Function Get-ClientProtocolMapping {
        param(
            [string]$FastName,
            [string]$AppPoolName,
            [string]$AspCounterName
        )
        $obj = New-Object PSCustomObject
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $FastName
        $obj | Add-Member -MemberType NoteProperty -Name "AppPoolName" -Value $AppPoolName
        $obj | Add-Member -MemberType NoteProperty -Name "AspCounterName" -Value $AspCounterName
        return $obj
    }

    $clientProtocolMappings = @{}
    $clientProtocolMappings.Add("AutoDFe", (Get-ClientProtocolMapping -FastName "AutoDFe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Autodiscover"))
    $clientProtocolMappings.Add("AutoDBe", (Get-ClientProtocolMapping -FastName "AutoDBe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Autodiscover"))
    $clientProtocolMappings.Add("EcpFe", (Get-ClientProtocolMapping -FastName "EcpFe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_ecp"))
    $clientProtocolMappings.Add("EcpBe", (Get-ClientProtocolMapping -FastName "EcpBe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_ecp"))
    $clientProtocolMappings.Add("MapiAddBook", (Get-ClientProtocolMapping -FastName "MapiAddBook" -AppPoolName "MSExchangeMapiAddressBookAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_nspi"))
    $clientProtocolMappings.Add("MapiFe", (Get-ClientProtocolMapping -FastName "MapiFe" -AppPoolName "MSExchangeMapiFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_mapi"))
    $clientProtocolMappings.Add("MapiBe", (Get-ClientProtocolMapping -FastName "MapiBe" -AppPoolName "MSExchangeMapiMailboxAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_emsdb"))
    $clientProtocolMappings.Add("OabFe", (Get-ClientProtocolMapping -FastName "OabFe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_OAB"))
    $clientProtocolMappings.Add("OabBe", (Get-ClientProtocolMapping -FastName "OabBe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_OAB"))
    $clientProtocolMappings.Add("OwaFe", (Get-ClientProtocolMapping -FastName "OwaFe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa"))
    $clientProtocolMappings.Add("OwaBe", (Get-ClientProtocolMapping -FastName "OwaBe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa"))
    $clientProtocolMappings.Add("OwaCalFe", (Get-ClientProtocolMapping -FastName "OwaCalFe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa_Calendar"))
    $clientProtocolMappings.Add("OwaCalBe", (Get-ClientProtocolMapping -FastName "OwaCalBe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa_Calendar"))
    $clientProtocolMappings.Add("PsFe", (Get-ClientProtocolMapping -FastName "PsFe" -AppPoolName "MSExchangePowerShellFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_PowerShell"))
    $clientProtocolMappings.Add("PsBe", (Get-ClientProtocolMapping -FastName "PsBe" -AppPoolName "MSExchangePowerShellAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_PowerShell"))
    $clientProtocolMappings.Add("RestFe", (Get-ClientProtocolMapping -FastName "RestFe" -AppPoolName "MSExchangeRestFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_API"))
    $clientProtocolMappings.Add("RestBe", (Get-ClientProtocolMapping -FastName "RestBe" -AppPoolName "MSExchangeRestAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_API"))
    $clientProtocolMappings.Add("RpcFe", (Get-ClientProtocolMapping -FastName "RpcFe" -AppPoolName "MSExchangeRpcProxyFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_rpc"))
    $clientProtocolMappings.Add("RpcBe", (Get-ClientProtocolMapping -FastName "RpcBe" -AppPoolName "MSExchangeRpcProxyAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_rpc"))
    $clientProtocolMappings.Add("EwsFe", (Get-ClientProtocolMapping -FastName "EwsFe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_EWS"))
    $clientProtocolMappings.Add("EwsBe", (Get-ClientProtocolMapping -FastName "EwsBe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_EWS"))
    $clientProtocolMappings.Add("EasFe", (Get-ClientProtocolMapping -FastName "EasFe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Microsoft-Server-ActiveSync"))
    $clientProtocolMappings.Add("EasBe", (Get-ClientProtocolMapping -FastName "EasBe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Microsoft-Server-ActiveSync"))

    return $clientProtocolMappings
}