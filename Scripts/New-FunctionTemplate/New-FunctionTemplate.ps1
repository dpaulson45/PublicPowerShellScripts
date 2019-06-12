[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$FunctionName,
[Parameter(Mandatory=$false)][bool]$IncludeTests = $true 
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionDirectory = "{0}\{1}\{2}" -f (Split-Path -Parent (Split-Path -Parent $here)), "Functions", $FunctionName

if(Test-Path $functionDirectory)
{
    Write-Host("Function already exists!")
    exit 
}

$defaultMainScriptContent = @"
Function {0} {1}
[CmdletBinding()]
param(
)
#[System.Collections.Generic.List[System.Object]]`$list = New-Object -TypeName System.Collections.Generic.List[System.Object]
#Function Version 1.0
<# 
Required Functions: 
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
#>

Write-VerboseWriter("Calling: {2}")

########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 

{3}
"@ -f $FunctionName, "{", $FunctionName, "}"

$defaultTestScriptContent = @"
`$here = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$sut = (Split-Path -Leaf `$MyInvocation.MyCommand.Path) -replace '\.Tests\.','.'
`$here = `$here.Replace("\Tests","")
. "`$here\`$sut"

#Load Required Functions

`$content = Get-Content "`$here\`$sut" 
`$foundRequiredFunctions = `$false 
foreach(`$line in `$content)
{
    if(`$foundRequiredFunctions)
    {
        if(`$line.Contains("#>"))
        {
            break 
        }
        `$webRequest = Invoke-WebRequest `$line.Trim()
        if(`$webRequest -ne `$null -and `$webRequest.Content)
        {
            Invoke-Expression `$webRequest.Content 
        }
    }
    if(`$line.Contains("Required Functions:"))
    {
        `$foundRequiredFunctions = `$true 
        continue
    }
}


"@

$defaultREADME = @"
# {0}
Function that is used to 
"@ -f $FunctionName

[System.IO.Directory]::CreateDirectory($functionDirectory) | Out-Null
if(!(Test-Path $functionDirectory))
{
    Write-Host("Failed to create function directory")
    exit 
}

if($IncludeTests)
{
    [System.IO.Directory]::CreateDirectory(($testDirectory = "{0}\Tests" -f $functionDirectory)) | Out-Null
    if(!(Test-Path $testDirectory))
    {
        Write-Host("Failed to create tests directory")
        exit 
    }
    New-Item -Path $testDirectory -Name ("{0}.Tests.ps1" -f $FunctionName) -ItemType File -Value $defaultTestScriptContent
}
New-Item -Path $functionDirectory -Name ("{0}.ps1" -f $FunctionName) -ItemType File -Value $defaultMainScriptContent 
New-Item -Path $functionDirectory -Name "README.md" -ItemType File -Value $defaultREADME 