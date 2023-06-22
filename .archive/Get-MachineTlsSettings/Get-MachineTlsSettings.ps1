<#
Name: Get-MachineTlsSettings.ps1
Author: David Paulson

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
    BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
[CmdletBinding()]
param(
$MachineName = $env:COMPUTERNAME
)
########################
#
# Template Functions
#
########################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Invoke-RegistryGetValue/Invoke-RegistryGetValue.ps1
Function Invoke-RegistryGetValue {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$RegistryHive = "LocalMachine",
[Parameter(Mandatory=$true)][string]$MachineName,
[Parameter(Mandatory=$true)][string]$SubKey,
[Parameter(Mandatory=$false)][string]$GetValue,
[Parameter(Mandatory=$false)][bool]$ReturnAfterOpenSubKey,
[Parameter(Mandatory=$false)][object]$DefaultValue,
[Parameter(Mandatory=$false)][scriptblock]$CatchActionFunction
)

#Function Version 1.2
<#
Required Functions:
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>
Write-VerboseWriter("Calling: Invoke-RegistryGetValue")
try
{
    Write-VerboseWriter("Attempting to open the Base Key '{0}' on Server '{1}'" -f $RegistryHive, $MachineName)
    $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegistryHive, $MachineName)
    Write-VerboseWriter("Attempting to open the Sub Key '{0}'" -f $SubKey)
    $RegKey= $Reg.OpenSubKey($SubKey)

    if ($ReturnAfterOpenSubKey)
    {
        Write-VerboseWriter("Returning OpenSubKey")
        return $RegKey
    }

    Write-VerboseWriter("Attempting to get the value '{0}'" -f $GetValue)
    $returnGetValue = $RegKey.GetValue($GetValue)

    if ($null -eq $returnGetValue -and
        $null -ne $DefaultValue)
    {
        Write-VerboseWriter("No value found in the registry. Setting to default value: {0}" -f $DefaultValue)
        $returnGetValue = $DefaultValue
    }

    Write-VerboseWriter("Exiting: Invoke-RegistryHandler | Returning: {0}" -f $returnGetValue)
    return $returnGetValue
}
catch
{
    if ($CatchActionFunction -ne $null)
    {
        & $CatchActionFunction
    }

    Write-VerboseWriter("Failed to open the registry")
}

}
# End Function Invoke-RegistryGetValue


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#Function Version 1.1
Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString
)
    if($Script:Logger -ne $null)
    {
        $Script:Logger.WriteHost($WriteString)
    }
    elseif($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
# End Function Write-VerboseWriter


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Get-AllTlsSettingsFromRegistry/Get-AllTlsSettingsFromRegistry.ps1
Function Get-AllTlsSettingsFromRegistry {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$MachineName,
[Parameter(Mandatory=$false)][scriptblock]$CatchActionFunction
)
#Function Version 1.0
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Invoke-RegistryGetValue/Invoke-RegistryGetValue.ps1
#>

Write-VerboseWriter("Calling: Get-AllTlsSettingsFromRegistry")
Write-VerboseWriter("Passed: [string]MachineName: {0}" -f $MachineName)

$registryBase = "SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS {0}\{1}"
$tlsVersions = @("1.0","1.1","1.2")

$tlsResults = @{}
$keyValues = ("Enabled","DisabledByDefault")

Function Set-TLSMemberValue {
param(
[Parameter(Mandatory=$true)][string]$GetKeyType,
[Parameter(Mandatory=$false)][object]$KeyValue,
[Parameter(Mandatory=$true)][string]$ServerClientType,
[Parameter(Mandatory=$true)][string]$TlsVersion 
)
    switch($GetKeyType)
    {
        "Enabled" {
            if($KeyValue -eq $null)
            {
                Write-VerboseWriter("Failed to get TLS {0} {1} Enabled Key on Server {2}. We are assuming this means it is enabled." -f $TlsVersion, $ServerClientType, $MachineName)
                return $true
            }
            else 
            {
                Write-VerboseWriter("{0} Enabled Value '{1}'" -f $ServerClientType, $serverValue)
                if($KeyValue -eq 1)
                {
                    return $true 
                }
                return $false 
            }
         }
        "DisabledByDefault" {
            if($KeyValue -ne $null)
            {
                Write-VerboseWriter("Failed to get TLS {0} {1} Disabled By Default Key on Server {2}. Setting to false." -f $TlsVersion, $ServerClientType, $MachineName)
                return $false 
            }
            else 
            {
                Write-VerboseWriter("{0} Disabled By Default Value '{1}'" -f $ServerClientType, $serverValue)
                if($KeyValue -eq 1)
                {
                    return $true
                }
                return $false 
            }
        }
    }
}

Function Set-NETDefaultTLSValue {
param(
[Parameter(Mandatory=$false)][object]$KeyValue,
[Parameter(Mandatory=$true)][string]$NetVersion,
[Parameter(Mandatory=$true)][string]$KeyName
)
    if($KeyValue -eq $null)
    {
        Write-VerboseWriter("Failed to get {0} registry value for .NET {1} version. Setting to false." -f $KeyName, $NetVersion)
        return $false
    }
    else 
    {
        Write-VerboseWriter("{0} value '{1}'" -f $KeyName, $KeyValue)
        if($KeyValue -eq 1)
        {
            return $true 
        }
        return $false 
    }
}

[hashtable]$allTlsObjects = @{}
foreach($tlsVersion in $tlsVersions)
{
    $registryServer = $registryBase -f $tlsVersion, "Server" 
    $registryClient = $registryBase -f $tlsVersion, "Client" 
    $currentTLSObject = New-Object PSCustomObject 
    $currentTLSObject | Add-Member -MemberType NoteProperty -Name "TLSVersion" -Value $tlsVersion

    foreach($getKey in $keyValues)
    {
        $memberServerName = "Server{0}" -f $getKey
        $memberClientName = "Client{0}" -f $getKey 

        $serverValue = Invoke-RegistryGetValue -RegistryHive "LocalMachine" -MachineName $MachineName -SubKey $registryServer -GetValue $getKey -CatchActionFunction $CatchActionFunction
        $clientValue = Invoke-RegistryGetValue -RegistryHive "LocalMachine" -MachineName $MachineName -SubKey $registryClient -GetValue $getKey -CatchActionFunction $CatchActionFunction

        $currentTLSObject | Add-Member -MemberType NoteProperty -Name $memberServerName -Value (Set-TLSMemberValue -GetKeyType $getKey -KeyValue $serverValue -ServerClientType "Server" -TlsVersion $tlsVersion)
        $currentTLSObject | Add-Member -MemberType NoteProperty -Name $memberClientName -Value (Set-TLSMemberValue -GetKeyType $getKey -KeyValue $clientValue -ServerClientType "Client" -TlsVersion $tlsVersion)

    }
    $allTlsObjects.Add($tlsVersion, $currentTLSObject)
}

$netVersions = @("v2.0.50727","v4.0.30319")
$registryBase = "SOFTWARE\{0}\.NETFramework\{1}"
foreach($netVersion in $netVersions)
{
    $currentNetTlsDefaultVersionObject = New-Object PSCustomObject 
    $currentNetTlsDefaultVersionObject | Add-Member -MemberType NoteProperty -Name "NetVersion" -Value $netVersion

    $SystemDefaultTlsVersions = Invoke-RegistryGetValue -RegistryHive "LocalMachine" -MachineName $MachineName -SubKey ($registryBase -f "Microsoft", $netVersion) -GetValue "SystemDefaultTlsVersions" -CatchActionFunction $CatchActionFunction
    $WowSystemDefaultTlsVersions = Invoke-RegistryGetValue -RegistryHive "LocalMachine" -MachineName $MachineName -SubKey ($registryBase -f "Wow6432Node\Microsoft", $netVersion) -GetValue "SystemDefaultTlsVersions" -CatchActionFunction $CatchActionFunction

    $currentNetTlsDefaultVersionObject | Add-Member -MemberType NoteProperty -Name "SystemDefaultTlsVersions" -Value (Set-NETDefaultTLSValue -KeyValue $SystemDefaultTlsVersions -NetVersion $netVersion -KeyName "SystemDefaultTlsVersions")
    $currentNetTlsDefaultVersionObject | Add-Member -MemberType NoteProperty -Name "WowSystemDefaultTlsVersions" -Value (Set-NETDefaultTLSValue -KeyValue $WowSystemDefaultTlsVersions -NetVersion $netVersion -KeyName "WowSystemDefaultTlsVersions")
    
    $hashKeyName = "NET{0}" -f ($netVersion.Split(".")[0])
    $allTlsObjects.Add($hashKeyName, $currentNetTlsDefaultVersionObject) 
}

return $allTlsObjects
}
# End Function Get-AllTlsSettingsFromRegistry



########################
#
# End Template Functions
#
########################

$results = Get-AllTlsSettingsFromRegistry -MachineName $MachineName

$tls = @("1.0","1.1","1.2")

foreach ($version in $tls)
{
    Write-Host("TLS Version: {0}" -f $version)
    $results[$version] | Format-List ServerEnabled,ClientEnabled,ServerDisabledByDefault,ClientDisabledByDefault
}

Write-Host("NETv4")
$results["NETv4"]| Format-List SystemDefaultTlsVersions,WowSystemDefaultTlsVersions
Write-Host("NETv2")
$results["NETv2"]| Format-List SystemDefaultTlsVersions,WowSystemDefaultTlsVersions