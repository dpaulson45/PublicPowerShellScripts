Function New-ExperfwizManagerObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][string]$ExperfwizDirectory = '.',
        [Parameter(Mandatory = $false)][string]$ExperfwizName = "Experfwiz.ps1",
        [Parameter(Mandatory = $false)][string]$SaveDirectory = ".",
        [Parameter(Mandatory = $false)][int]$MaxFileSize = 4096,
        [Parameter(Mandatory = $false)][int]$Interval,
        [Parameter(Mandatory = $false)][bool]$EnableCircular = $true,
        [Parameter(Mandatory = $false)][array]$Servers,
        [Parameter(Mandatory = $false)][scriptblock]$HostFunctionCaller,
        [Parameter(Mandatory = $false)][scriptblock]$VerboseFunctionCaller
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>

    ########## Parameter Binding Exceptions ##############

    if ([string]::IsNullOrWhiteSpace($ExperfwizDirectory) -or (!(Test-Path $ExperfwizDirectory))) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExperfwizDirectory"
    }
    $fullExperfwizPath = "{0}\{1}" -f $ExperfwizDirectory, $ExperfwizName
    if (!(Test-Path $fullExperfwizPath)) {
        $throwString = "Failed to provide valid full path to {0} script" -f $ExperfwizName
        throw [System.Management.Automation.ParameterBindingException] $throwString
    }
    if ($MaxFileSize -lt 1024) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxFileSize. Must be equal or greater than 1024."
    }
    if ($Interval -lt 1 -and $Interval -gt 60) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Interval. Must be value greater than 0 and less than 60."
    }
    if ($null -eq $Servers -or
        $Servers.Count -eq 0) {
        $Servers = @($env:COMPUTERNAME)
    }
    if ($SaveDirectory -eq '.') {
        $SaveDirectory = (Get-Location).Path
    }

    $experfwizManager = New-Object PSCustomObject
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "ExperfwizDirectory" -Value $ExperfwizDirectory
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "FullExperfwizPath" -Value $fullExperfwizPath
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "SaveDirectory" -Value $SaveDirectory
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "MaxFileSize" -Value $MaxFileSize
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "Interval" -Value $Interval
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "EnableCircular" -Value $EnableCircular
    $experfwizManager | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}

    if ($null -ne $HostFunctionCaller) {
        $experfwizManager | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $experfwizManager | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {

        foreach ($server in $this.Servers) {
            & $this.FullExperfwizPath -stop -server $server
        }
    }

    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "StartSuccessful" -Value {
        param(
            [string]$Server
        )
        $results = logman Exchange_Perfwiz -s $Server

        foreach ($line in $results) {
            if ($line.StartsWith("Status:")) {
                if ($line.Contains("Running")) {
                    return $true
                } else {
                    return $false
                }
            }
        }
    }

    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "Start" -Value {

        foreach ($server in $this.Servers) {
            $attempts = 0
            $maxAttempts = 10
            [int]$maxSize = $this.MaxFileSize
            do {
                & $this.FullExperfwizPath -interval $this.Interval -circular -filepath $this.SaveDirectory -server $server -maxsize $maxSize -quiet
                $maxSize++
            }while ((!($this.StartSuccessful($server))) -and $attempts -lt $maxAttempts)
        }
    }

    return $experfwizManager
}