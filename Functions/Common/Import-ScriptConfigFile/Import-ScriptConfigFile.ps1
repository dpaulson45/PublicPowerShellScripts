Function Import-ScriptConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptConfigFileLocation,
        [Parameter(Mandatory = $false)][string]$MainSplitLineValue = "~"
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Common/Write-VerboseWriters/Write-VerboseWriter.ps1
    #>

    Write-VerboseWriter("Calling: Import-ScriptConfigFile")
    Write-VerboseWriter("Passed: [string]ScriptConfigFileLocation: {0} | [string]MainSplitLineValue: {1}" -f $ScriptConfigFileLocation, $MainSplitLineValue)

    Function Get-SystemConvertValue {
        param(
            [Parameter(Mandatory = $true)][string]$Value,
            [Parameter(Mandatory = $true)][string]$Type
        )
        Write-VerboseWriter("Calling: Get-SystemConvertValue")
        Write-VerboseWriter("Passed: [string]Value: {0} | [string]Type: {1}" -f $Value, $Type)
        if ($Type -eq "int") {
            $variableValue = [System.Convert]::ToInt32($Value)
        } elseif ($Type -eq "double") {
            $variableValue = [System.Convert]::ToDouble($Value)
        } elseif ($Type -eq "int64") {
            $variableValue = [System.Convert]::ToInt64($Value)
        }

        return $variableValue
    }

    if (!(Test-Path $ScriptConfigFileLocation)) {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ScriptConfigFileLocation"
    }
    $readContent = Get-Content $ScriptConfigFileLocation

    foreach ($line in $readContent) {
        Write-VerboseWriter("Working on line: {0}" -f $line)
        $splitInfo = $line.Split($MainSplitLineValue)
        $variableName = $splitInfo[0]
        $fullVariableType = $splitInfo[1]
        $variableValue = $splitInfo[2]

        if ($fullVariableType -like "GetContent*") {
            Write-VerboseWriter("Detected GetContent")
            if (Test-Path $variableValue) {
                $variableValue = Get-Content $variableValue
            } else {
                Write-VerboseWriter("Failed to find {0}. Going to move on." -f $variableValue)
                continue
            }
        } elseif ($fullVariableType -like "array*") {
            Write-VerboseWriter("Detected array")
            $variableTypeSplit = $fullVariableType.Split("=")
            $type = $variableTypeSplit[1]
            $splitArrayValue = $variableTypeSplit[2]
            $variableValue = $variableValue.Split($splitArrayValue)
            if ($type -ne "string") {
                Write-VerboseWriter("Determined array isn't a string type converting")
                $tempArray = @()
                foreach ($value in $variableValue) {
                    $tempArray += Get-SystemConvertValue -Value $value -Type $type
                }

                $variableValue = $tempArray
            }
        } elseif ($fullVariableType -like "bool*") {
            Write-VerboseWriter("Detected boolean type")
            if ($variableValue -eq "false") {
                $variableValue = $false
            } else {
                $variableValue = $true
            }
        } elseif ($fullVariableType -eq "int" -or
            $fullVariableType -eq "double" -or
            $fullVariableType -eq "int64") {
            Write-VerboseWriter("Detected a number type value")
            $variableValue = Get-SystemConvertValue -Value $variableValue -Type $fullVariableType
        }
        Set-Variable -Name $variableName -Value $variableValue -Scope Script
    }
}