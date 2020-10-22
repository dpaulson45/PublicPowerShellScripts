Function Get-Smb1ServerSettings {
[CmdletBinding()]
param(
[string]$ServerName = $env:COMPUTERNAME,
[bool]$Windows2012R2OrGreater = $true,
[scriptblock]$CatchActionFunction
)
#Function Version 1.1
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Invoke-RegistryGetValue/Invoke-RegistryGetValue.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Invoke-ScriptBlockHandler/Invoke-ScriptBlockHandler.ps1
#>

Write-VerboseWriter("Calling: Get-Smb1ServerSettings")
Write-VerboseWriter("Passed ServerName: {0} | Windows2012R2OrGreater: {1}" -f $ServerName, $Windows2012R2OrGreater)
$regSmb1ServerSettings = Invoke-RegistryGetValue -MachineName $ServerName -SubKey "SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -GetValue "SMB1" -CatchActionFunction $CatchActionFunction
$smbServerConfiguration = Invoke-ScriptBlockHandler -ComputerName $ServerName -ScriptBlock {Get-SmbServerConfiguration} -CatchActionFunction $CatchActionFunction -ScriptBlockDescription "Get-SmbServerConfiguration"

if ($Windows2012R2OrGreater)
{
    try
    {
        $windowsFeature = Get-WindowsFeature "FS-SMB1" -ComputerName $ServerName -ErrorAction Stop
    }
    catch 
    {
        Write-VerboseWriter("Failed to Get-WindowsFeature for FS-SMB1")
        if ($CatchActionFunction -ne $null)
        {
            & $CatchActionFunction
        }
    }
}

[int]$smb1Status = 2
if (($smbServerConfiguration.EnabledSMB1Protocol -and
    $windowsFeature.Installed) -or
    $regSmb1ServerSettings -ne 0)
{
    $smb1Status = 0
}
elseif ($smbServerConfiguration.EnabledSMB1Protocol -or
    $windowsFeature.Installed -or
    $regSmb1ServerSettings -ne 0)
{
    $smb1Status = 1
}

$smb1ServerSettings = New-Object PSCustomObject
$smb1ServerSettings | Add-Member -MemberType NoteProperty -Name "RegistryValue" -Value $regSmb1ServerSettings
$smb1ServerSettings | Add-Member -MemberType NoteProperty -Name "SmbServerConfiguration" -Value $smbServerConfiguration
$smb1ServerSettings | Add-Member -MemberType NoteProperty -Name "WindowsFeature" -Value $windowsFeature
$smb1ServerSettings | Add-Member -MemberType NoteProperty -Name "Smb1Status" -Value $smb1Status

return $smb1ServerSettings

}