[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][switch]$UpdateAllInScript,
[Parameter(Mandatory=$false)][string]$WebUri, 
[Parameter(Mandatory=$true)][string]$ScriptLocation
)

Function Update-Function {
param(
[Parameter(Mandatory=$true)][string]$WebUri
)
$webResponse = Invoke-WebRequest $WebUri

if($webResponse.StatusCode -ne 200)
{
    throw "Failed to return a 200 status back from web request"
}

$webContent = $webResponse.Content 
$functionName = $WebUri.Substring(($WebUri.LastIndexOf("/")) + 1).Replace(".ps1","")

if($webContent.Contains("Template Functions"))
{
    $webContent = $webContent.Replace("Template Functions",("{0} -- Template Functions" -f $functionName))
}

$scriptContent = Get-Content $ScriptLocation
$startIndex = 0 
while($startIndex -lt $scriptContent.count)
{
    if($scriptContent[$startIndex] -like ("*Function {0}*" -f $functionName))
    {
        break; 
    }
    $startIndex++
}

$fullAdd = $false 

if($startIndex -eq $scriptContent.count)
{
    $startIndex = 0
    while($startIndex -lt $scriptContent.count)
    {
        if($scriptContent[$startIndex] -like "*Template Functions*")
        {
            do{
                $startIndex++
            }while($scriptContent[$startIndex].StartsWith("#") -or $scriptContent[$startIndex].Trim() -eq $null)
            $fullAdd = $true 
            break; 
        }
        $startIndex++
    }
}

Write-Debug("Test")

$updateScript = @()
$index = 0
while($index -lt $startIndex)
{
    $updateScript += $scriptContent[$index++]
}

if($fullAdd)
{
    $updateScript += ""
    $updateScript += "# Template Master: {0}" -f $WebUri
    $updateScript += $webContent
    $updateScript += "# End Function {0}" -f $functionName
    $updateScript += ""
}
else 
{
    $endIndex = $startIndex
    while($endIndex -lt $scriptContent.Count)
    {
        if($scriptContent[$endIndex] -eq "# End Function {0}" -f $functionName)
        {
            break; 
        }
        $endIndex++
    }

    $index = $endIndex
    $updateScript += $webContent
}
while($index -lt $scriptContent.count)
{
    $updateScript += $scriptContent[$index++]
}

#rename current script file 
$backupCopy = $ScriptLocation.Replace(".ps1",".bak")
if(Test-Path $backupCopy)
{
    Remove-Item $backupCopy -Force 
}
Rename-Item -Path $ScriptLocation -NewName $backupCopy
Write-Debug("before out-file")
$updateScript | Out-File $ScriptLocation -Encoding ASCII 

}

if($UpdateAllInScript)
{
    $functionMastersUri = @() 
    $scriptContent = Get-Content $ScriptLocation
    $index = 0 
    while($index -lt $scriptContent.count)
    {
        if($scriptContent[$index] -like "# Template Master:*")
        {
            $currentUri = $scriptContent[$index].Replace("# Template Master: ","")
            $functionMastersUri += $currentUri
            $functionName = $currentUri.Substring(($currentUri.LastIndexOf("/")) + 1).Replace(".ps1","")
            do{
                $index++
            }while($scriptContent[$index] -ne ("# End Function {0}" -f $functionName) -or $index -eq $scriptContent.Count)
        }
        $index++
    }

    foreach($WebUri in $functionMastersUri)
    {
        Update-Function -WebUri $WebUri
    }
}
else
{
    Update-Function -WebUri $WebUri
}