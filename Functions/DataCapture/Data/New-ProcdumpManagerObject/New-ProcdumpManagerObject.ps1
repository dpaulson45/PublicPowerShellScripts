Function New-ProcdumpManagerObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '', Justification = 'Not sure why i am doing this at the moment, need to look into it')]
    [CmdletBinding()]
    param(
        [string]$BinaryProcdumpExe = ".\procdump.exe",
        [string]$ProcessName,
        [hashtable]$ProcessIDToServer,
        [string]$DumpFolder,
        [bool]$DumpWithMA = $true,
        [bool]$DumpWithMP = $false,
        [int]$NumberOfDumps = 3,
        [int]$SecondsWait = 30,
        [array]$Servers,
        [bool]$VerboseEnabled = $false,
        [object]$LoggerObject,
        [scriptblock]$HostFunctionCaller,
        [scriptblock]$VerboseFunctionCaller
    )
    #This Script requires Invoke-Command to be able to be run, even locally.
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-HostWriters/Write-ScriptMethodHostWriter.ps1
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-ScriptMethodVerboseWriter.ps1
    #>
    <#
    #TODO List:
    - Add Verbose information
    - Add debug status info for dumping out the information when attempting to execute procdump
    #>

    ########## Parameter Binding Exceptions ##############
    if ([string]::IsNullOrEmpty($BinaryProcdumpExe)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BinaryProcdumpExe."
    }
    if (([string]::IsNullOrEmpty($ProcessName) -and
            ($null -eq $ProcessIDToServer)) -or
        (!([string]::IsNullOrEmpty($ProcessName)) -and
            ($null -ne $ProcessIDToServer))) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ProcessName or ProcessIDToServer. Only one must be used."
    }
    if (!([string]::IsNullOrEmpty($ProcessName)) -and
        $ProcessName.EndsWith(".exe")) {
        $ProcessName = $ProcessName.Replace(".exe", "")
    }
    if ([string]::IsNullOrEmpty($DumpFolder)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid DumpFolder."
    }
    if (!($DumpFolder.EndsWith("\"))) {
        $DumpFolder = $DumpFolder + "\"
    }
    if (($DumpWithMA -eq $true -and
            $DumpWithMP -eq $true) -or
        ($DumpWithMA -eq $false -and
            $DumpWithMP -eq $false)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid dump type. Either DumpWithMA or DumpWithMP must be set to true."
    }
    if ($null -eq $NumberOfDumps -or
        $NumberOfDumps -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid NumberOfDumps. Must be value greater than or equal to 1."
    }
    if ($null -eq $SecondsWait -or
        $SecondsWait -lt 0) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SecondsWait. Must be a value greater than or equal to 0."
    }
    if ($null -eq $Servers -or
        $Servers.Count -lt 1) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BinaryProcdumpExe"
    }

    Function Test-ValidProcdumpPath {
        foreach ($server in $Servers) {
            [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {
                param($passedArg)
                $test = Test-Path $passedArg
                return $test
            } -ArgumentList $BinaryProcdumpExe

            if (!($result)) {
                $throwString = "Failed to provide a valid path to procdump binary on server: {0}" -f $server
                throw [System.Management.Automation.ParameterBindingException] $throwString
            }
        }
    }

    Function Test-ValidDumpPath {
        foreach ($server in $Servers) {
            [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {
                param($passedArg)
                $test = Test-Path $passedArg
                return $test
            } -ArgumentList $DumpFolder

            if (!($result)) {
                $throwString = "Failed to provide a valid path to dump out the data to on server: {0}" -f $server
                throw [System.Management.Automation.ParameterBindingException] $throwString
            }
        }
    }

    Function Test-ValidHashTableKeys {
        foreach ($server in $Servers) {
            if (!($ProcessIDToServer.ContainsKey($server))) {
                $throwString = "Failed to provide a key of {0} in the ProcessIDToServer hashtable" -f $server
                throw [System.Management.Automation.ParameterBindingException] $throwString
            }
        }
    }

    Function Test-UsingProcessIDToServer {
        if ($null -eq $ProcessIDToServer) {
            return $false
        }
        return $true
    }

    Test-ValidProcdumpPath
    Test-ValidDumpPath
    if (Test-UsingProcessIDToServer) {
        Test-ValidHashTableKeys
    }

    $procdumpManagerObject = New-Object PSCustomObject

    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "BinaryProcdumpExe" -Value $BinaryProcdumpExe
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "ProcessName" -Value $ProcessName
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "ProcessIDToServer" -Value $ProcessIDToServer
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "DumpFolder" -Value $DumpFolder
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "DumpWithMA" -Value $DumpWithMA
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "NumberOfDumps" -Value $NumberOfDumps
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "SecondsWait" -Value $SecondsWait
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "WriteVerboseData" -Value $VerboseEnabled
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "LoggerObject" -Value $LoggerObject
    $procdumpManagerObject | Add-Member -MemberType NoteProperty -Name "UsingProcessIDToServer" -Value (Test-UsingProcessIDToServer)
    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-ScriptMethodVerboseWriter}
    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-ScriptMethodHostWriter}

    if ($null -ne $HostFunctionCaller) {
        $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
    }
    if ($null -ne $VerboseFunctionCaller) {
        $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
    }

    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "ValidateProcessOnServers" -Value {
        if ($this.UsingProcessIDToServer) {
            $processIdToServer = $this.ProcessIDToServer
            foreach ($key in $processIdToServer.Keys) {
                $processId = $processIdToServer[$key]
                [bool]$result = Invoke-Command -ComputerName $key -ScriptBlock {
                    param($passedArg)
                    $getProcess = Get-Process -Id $passedArg -ErrorAction SilentlyContinue
                    if ($null -eq $getProcess) {
                        return $false
                    }
                    return $true
                } -ArgumentList $processId

                if (!($result)) {
                    #for now do a return false: TODO: return a failure result as it is possible that process could change while we are monitoring.
                    $writeHost = "Failed to get the process ID: {0} from Server: {1}" -f $processId, $key
                    $this.WriteHostWriter($writeHost)
                    return $false
                }
            }
            return $true
        } else {
            $processName = $this.ProcessName
            foreach ($server in $this.Servers) {
                [bool]$result = Invoke-Command -ComputerName $server -ScriptBlock {
                    param($passedArg)
                    $getProcess = Get-Process $passedArg -ErrorAction SilentlyContinue
                    if ($null -eq $getProcess) {
                        return $false
                    }
                    return $true
                } -ArgumentList $processName

                if (!($result)) {
                    $writeHost = "Failed to find the process name of '{0}' on server {1}" -f $processName, $server
                    $this.WriteHostWriter($writeHost)
                    return $false
                }
            }
            return $true
        }
    }

    $procdumpManagerObject | Add-Member -MemberType ScriptMethod -Name "DumpOnServer" -Value {
        param(
            [string]$Server
        )
        if ([string]::IsNullOrEmpty($Server) -or
            (!($this.Servers.ToLower().Contains($Server.ToLower())))) {
            throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Server parameter"
        }

        if ($this.UsingProcessIDToServer) {
            $processId = $this.ProcessIDToServer[$Server]
        } else {
            $processId = $this.ProcessName
        }
        if ($this.DumpWithMA) {
            $dumpSwitch = "-ma"
        } else {
            $dumpSwitch = "-mp"
        }
        $argList = New-Object PSCustomObject
        $argList | Add-Member -MemberType NoteProperty -Name "BinaryProcdumpExe" -Value $this.BinaryProcdumpExe
        $argList | Add-Member -MemberType NoteProperty -Name "ProcessId" -Value $processId
        $argList | Add-Member -MemberType NoteProperty -Name "DumpSwitch" -Value $dumpSwitch
        $argList | Add-Member -MemberType NoteProperty -Name "DumpFolder" -Value $this.DumpFolder
        $argList | Add-Member -MemberType NoteProperty -Name "NumberOfDumps" -Value $this.NumberOfDumps
        $argList | Add-Member -MemberType NoteProperty -Name "Seconds" -Value $this.SecondsWait

        Invoke-Command -ComputerName $Server -ScriptBlock {
            param($passedArg)
            $procDump = $passedArg.BinaryProcdumpExe
            $processId = $passedArg.ProcessId
            $dumpSwitch = $passedArg.DumpSwitch
            $dumpFolder = $passedArg.DumpFolder
            $numberOfDumps = $passedArg.NumberOfDumps
            $seconds = $passedArg.Seconds
            & $procDump $dumpSwitch $processId $dumpFolder -n $numberOfDumps -s $seconds -accepteula
        } -ArgumentList $argList
    }

    return $procdumpManagerObject
}