Function New-ExperfwizManagerObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$ExperfwizDirectory = '.',
[Parameter(Mandatory=$false)][string]$ExperfwizName = "Experfwiz.ps1",
[Parameter(Mandatory=$false)][string]$SaveDirectory = ".",
[Parameter(Mandatory=$false)][int]$MaxFileSize = 4096,
[Parameter(Mandatory=$false)][int]$Interval,
[Parameter(Mandatory=$false)][bool]$EnableCircular = $true,
[Parameter(Mandatory=$false)][array]$Servers,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller
)

#Function Version 1.0
#[System.Collections.Generic.List[System.Object]]$list = New-Object -TypeName System.Collections.Generic.List[System.Object]

########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($this.VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        $this.VerboseFunctionCaller($WriteString)
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($this.HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        $this.HostFunctionCaller($WriteString)
    }
}

########################
#
# Template Functions
#
########################


########################
#
# End Template Functions
#
########################


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

if([string]::IsNullOrWhiteSpace($ExperfwizDirectory) -or (!(Test-Path $ExperfwizDirectory)))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ExperfwizDirectory" 
}
$fullExperfwizPath = "{0}\{1}" -f $ExperfwizDirectory, $ExperfwizName
if(!(Test-Path $fullExperfwizPath))
{
    $throwString = "Failed to provide valid full path to {0} script" -f $ExperfwizName 
    throw [System.Management.Automation.ParameterBindingException] $throwString
}
if($MaxFileSize -lt 1024)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaxFileSize. Must be equal or greater than 1024."
}
if($Interval -lt 1 -and $Interval -gt 60)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Interval. Must be value greater than 0 and less than 60."
}
if($Servers -eq $null -or $Servers.Count -eq 0)
{
    $Servers = @($env:COMPUTERNAME)
}
if($SaveDirectory -eq '.')
{
    $SaveDirectory = (Get-Location).Path
}

$experfwizManager = New-Object pscustomobject 
$experfwizManager | Add-Member -MemberType NoteProperty -Name "ExperfwizDirectory" -Value $ExperfwizDirectory
$experfwizManager | Add-Member -MemberType NoteProperty -Name "FullExperfwizPath" -Value $fullExperfwizPath 
$experfwizManager | Add-Member -MemberType NoteProperty -Name "SaveDirectory" -Value $SaveDirectory
$experfwizManager | Add-Member -MemberType NoteProperty -Name "MaxFileSize" -Value $MaxFileSize
$experfwizManager | Add-Member -MemberType NoteProperty -Name "Interval" -Value $Interval
$experfwizManager | Add-Member -MemberType NoteProperty -Name "EnableCircular" -Value $EnableCircular
$experfwizManager | Add-Member -MemberType NoteProperty -Name "Servers" -Value $Servers
$experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteHostWriter" -Value ${Function:Write-HostWriter}
$experfwizManager | Add-Member -MemberType ScriptMethod -Name "WriteVerboseWriter" -Value ${Function:Write-VerboseWriter}


if($HostFunctionCaller -ne $null)
{
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "HostFunctionCaller" -Value $HostFunctionCaller
}
if($VerboseFunctionCaller -ne $null)
{
    $experfwizManager | Add-Member -MemberType ScriptMethod -Name "VerboseFunctionCaller" -Value $VerboseFunctionCaller
}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {

    foreach($server in $this.Servers)
    {
        & $this.FullExperfwizPath -stop -server $server 
    }
}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "StartSuccessful" -Value {
    param(
    [string]$Server 
    )
    $results = logman Exchange_Perfwiz -s $Server 

    foreach($line in $results)
    {
        if($line.StartsWith("Status:"))
        {
            if($line.Contains("Running"))
            {
                return $true 
            }
            else 
            {
                return $false 
            }
        }
    }

}

$experfwizManager | Add-Member -MemberType ScriptMethod -Name "Start" -Value {

    foreach($server in $this.Servers)
    {
        $attempts = 0 
        $maxAttempts = 10 
        [int]$maxSize = $this.MaxFileSize 
        do{
            & $this.FullExperfwizPath -interval $this.Interval -circular -filepath $this.SaveDirectory -server $server -maxsize $maxSize -quiet
            $maxSize++
        }while((!($this.StartSuccessful($server))) -and $attempts -lt $maxAttempts)
    }

}

return $experfwizManager

}