[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][ValidateScript({$_.ToString().EndsWith("\")})][string]$FilePath,
[Parameter(Mandatory=$false)][scriptblock]$VerboseFunctionCaller,
[Parameter(Mandatory=$false)][scriptblock]$HostFunctionCaller
)


#Function Version 1.0
Function Write-VerboseWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($VerboseFunctionCaller -eq $null)
        {
            Write-Verbose $WriteString
        }
        else 
        {
            &$VerboseFunctionCaller $WriteString
        }
    }
    
    Function Write-HostWriter {
    param(
    [Parameter(Mandatory=$true)][string]$WriteString 
    )
        if($HostFunctionCaller -eq $null)
        {
            Write-Host $WriteString
        }
        else
        {
            &$HostFunctionCaller $WriteString    
        }
    }
$passedVerboseFunctionCaller = $false
$passedHostFunctionCaller = $false
if($VerboseFunctionCaller -ne $null){$passedVerboseFunctionCaller = $true}
if($HostFunctionCaller -ne $null){$passedHostFunctionCaller = $true}
Write-VerboseWriter("Calling: Get-FreeSpace")
Write-VerboseWriter("Passed: [string]FilePath: {0} | [scriptblock]VerboseFunctionCaller: {1} | [scriptblock]HostFunctionCaller: {2}" -f $FilePath,
$passedVerboseFunctionCaller,
$passedHostFunctionCaller)

Function Update-TestPath {
param(
[Parameter(Mandatory=$true)][string]$FilePath 
)
    $updateFilePath = $FilePath.Substring(0,$FilePath.LastIndexOf("\", $FilePath.Length - 2)+1)
    return $updateFilePath
}

Function Get-MountPointItemTarget{
param(
[Parameter(Mandatory=$true)][string]$FilePath 
)
    $itemTarget = [string]::Empty
    if(Test-Path $testPath)
    {
        $item = Get-Item $FilePath
        if($item.Target -like "Volume{*}\")
        {
            Write-VerboseWriter("File Path appears to be a mount point target: {0}" -f $item.Target)
            $itemTarget = $item.Target
        }
        else {
            Write-VerboseWriter("Path didn't appear to be a mount point target")    
        }
    }
    else {
        Write-VerboseWriter("Path isn't a true path yet.")
    }
    return $itemTarget    
}

$drivesList = Get-WmiObject Win32_Volume -Filter "drivetype = 3"
$testPath = $FilePath
$freeSpaceSize = -1 
while($true)
{
    if($testPath -eq [string]::Empty)
    {
        Write-HostWriter("Unable to fine a drive that matches the file path: {0}" -f $FilePath)
        break
    }
    Write-VerboseWriter("Trying to find path that matches path: {0}" -f $testPath)
    foreach($drive in $drivesList)
    {
        if($drive.Name -eq $testPath)
        {
            Write-VerboseWriter("Found a match")
            $freeSpaceSize = $drive.FreeSpace / 1GB 
            Write-VerboseWriter("Have {0}GB of Free Space" -f $freeSpaceSize)
            return $freeSpaceSize
        }
        Write-VerboseWriter("Drive name: '{0}' didn't match" -f $drive.Name)
    }

    $itemTarget = Get-MountPointItemTarget -FilePath $testPath
    if($itemTarget -ne [string]::Empty)
    {
        foreach($drive in $drivesList)
        {
            if($drive.DeviceID.Contains($itemTarget))
            {
                $freeSpaceSize = $drive.FreeSpace / 1GB 
                Write-VerboseWriter("Have {0}GB of Free Space" -f $freeSpaceSize)
                return $freeSpaceSize
            }
            Write-VerboseWriter("DeviceID didn't appear to match: {0}" -f $drive.DeviceID)
        }
        if($freeSpaceSize -eq -1)
        {
            Write-HostWriter("Unable to fine a drive that matches the file path: {0}" -f $FilePath)
            Write-HostWriter("This shouldn't have happened.")
            break
        }

    }

    $testPath = Update-TestPath -FilePath $testPath
}

return $freeSpaceSize