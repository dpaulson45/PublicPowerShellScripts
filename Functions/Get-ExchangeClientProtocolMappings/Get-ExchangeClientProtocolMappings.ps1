Function Get-ExchangeClientProtocolMappings {

#Function Version 1.0
Function New-ClientProtocolMapping {
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
$clientProtocolMappings.Add("AutoDFe", (New-ClientProtocolMapping -FastName "AutoDFe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Autodiscover"))
$clientProtocolMappings.Add("AutoDBe", (New-ClientProtocolMapping -FastName "AutoDBe" -AppPoolName "MSExchangeAutodiscoverAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Autodiscover"))
$clientProtocolMappings.Add("EcpFe", (New-ClientProtocolMapping -FastName "EcpFe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_ecp"))
$clientProtocolMappings.Add("EcpBe", (New-ClientProtocolMapping -FastName "EcpBe" -AppPoolName "MSExchangeEcpAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_ecp"))
$clientProtocolMappings.Add("MapiAddBook", (New-ClientProtocolMapping -FastName "MapiAddBook" -AppPoolName "MSExchangeMapiAddressBookAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_nspi"))
$clientProtocolMappings.Add("MapiFe", (New-ClientProtocolMapping -FastName "MapiFe" -AppPoolName "MSExchangeMapiFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_mapi"))
$clientProtocolMappings.Add("MapiBe", (New-ClientProtocolMapping -FastName "MapiBe" -AppPoolName "MSExchangeMapiMailboxAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_mapi_emsdb"))
$clientProtocolMappings.Add("OabFe", (New-ClientProtocolMapping -FastName "OabFe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_OAB"))
$clientProtocolMappings.Add("OabBe", (New-ClientProtocolMapping -FastName "OabBe" -AppPoolName "MSExchangeOabAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_OAB"))
$clientProtocolMappings.Add("OwaFe", (New-ClientProtocolMapping -FastName "OwaFe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa"))
$clientProtocolMappings.Add("OwaBe", (New-ClientProtocolMapping -FastName "OwaBe" -AppPoolName "MSExchangeOwaAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa"))
$clientProtocolMappings.Add("OwaCalFe", (New-ClientProtocolMapping -FastName "OwaCalFe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_owa_Calendar"))
$clientProtocolMappings.Add("OwaCalBe", (New-ClientProtocolMapping -FastName "OwaCalBe" -AppPoolName "MSExchangeOwaCalendarAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_owa_Calendar"))
$clientProtocolMappings.Add("PsFe", (New-ClientProtocolMapping -FastName "PsFe" -AppPoolName "MSExchangePowerShellFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_PowerShell"))
$clientProtocolMappings.Add("PsBe", (New-ClientProtocolMapping -FastName "PsBe" -AppPoolName "MSExchangePowerShellAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_PowerShell"))
$clientProtocolMappings.Add("RestFe", (New-ClientProtocolMapping -FastName "RestFe" -AppPoolName "MSExchangeRestFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_API"))
$clientProtocolMappings.Add("RestBe", (New-ClientProtocolMapping -FastName "RestBe" -AppPoolName "MSExchangeRestAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_API"))
$clientProtocolMappings.Add("RpcFe", (New-ClientProtocolMapping -FastName "RpcFe" -AppPoolName "MSExchangeRpcProxyFrontEndAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_rpc"))
$clientProtocolMappings.Add("RpcBe", (New-ClientProtocolMapping -FastName "RpcBe" -AppPoolName "MSExchangeRpcProxyAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_rpc"))
$clientProtocolMappings.Add("EwsFe", (New-ClientProtocolMapping -FastName "EwsFe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_EWS"))
$clientProtocolMappings.Add("EwsBe", (New-ClientProtocolMapping -FastName "EwsBe" -AppPoolName "MSExchangeServicesAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_EWS"))
$clientProtocolMappings.Add("EasFe", (New-ClientProtocolMapping -FastName "EasFe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_1_ROOT_Microsoft-Server-ActiveSync"))
$clientProtocolMappings.Add("EasBe", (New-ClientProtocolMapping -FastName "EasBe" -AppPoolName "MSExchangeSyncAppPool" -AspCounterName "_LM_W3SVC_2_ROOT_Microsoft-Server-ActiveSync"))
        
return $clientProtocolMappings
}