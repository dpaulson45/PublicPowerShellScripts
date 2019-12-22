Function Compress-Folder {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Folder,
[Parameter(Mandatory=$false)][bool]$IncludeMonthDay = $false,
[Parameter(Mandatory=$false)][bool]$IncludeDisplayZipping = $true,
[Parameter(Mandatory=$false)][bool]$ReturnCompressedLocation = $false
)

#Function Version 1.3
<#
Required Functions:
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-VerboseWriters/Write-VerboseWriter.ps1
    https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Write-HostWriters/Write-HostWriter.ps1
#>

Function Get-DirectorySize {
param(
[Parameter(Mandatory=$true)][string]$Directory,
[Parameter(Mandatory=$false)][bool]$IsCompressed = $false 
)
    Write-VerboseWriter("Calling: Get-DirectorySize")
    Write-VerboseWriter("Passed: [string]Directory: {0} | [bool]IsCompressed: {1}" -f $Directory, $IsCompressed)
    $itemSize = 0
    if($IsCompressed)
    {
        $itemSize = (Get-Item $Directory).Length 
    }
    else 
    {
        $childItems = Get-ChildItem $Directory -Recurse | Where-Object{-not($_.Mode.StartsWith("d-"))}
        foreach($item in $childItems)
        {
            $itemSize += $item.Length
        }
    }
    return $itemSize
}
Function Enable-IOCompression
{
    $successful = $true 
    Write-VerboseWriter("Calling: Enable-IOCompression")
    try 
    {
        Add-Type -AssemblyName System.IO.Compression.Filesystem -ErrorAction Stop
    }
    catch 
    {
        Write-HostWriter("Failed to load .NET Compression assembly. Unable to compress up the data.")
        $successful = $false 
    }
    Write-VerboseWriter("Returned: [bool]{0}" -f $successful)
    return $successful
}
Function Confirm-IOCompression 
{
    Write-VerboseWriter("Calling: Confirm-IOCompression")
    $assemblies = [Appdomain]::CurrentDomain.GetAssemblies()
    $successful = $false
    foreach($assembly in $assemblies)
    {
        if($assembly.Location -like "*System.IO.Compression.Filesystem*")
        {
            $successful = $true 
            break 
        }
    }
    Write-VerboseWriter("Returned: [bool]{0}" -f $successful)
    return $successful
}

Function Compress-Now
{
    Write-VerboseWriter("Calling: Compress-Now ")
    $zipFolder = Get-ZipFolderName -Folder $Folder -IncludeMonthDay $IncludeMonthDay
    if($IncludeDisplayZipping)
    {
        Write-HostWriter("Compressing Folder {0}" -f $Folder)
    }
    $sizeBytesBefore = Get-DirectorySize -Directory $Folder
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Folder, $zipFolder)
    $timer.Stop()
    $sizeBytesAfter = Get-DirectorySize -Directory $zipFolder -IsCompressed $true
    Write-VerboseWriter("Compressing directory size of {0} MB down to the size of {1} MB took {2} seconds." -f ($sizeBytesBefore / 1MB), ($sizeBytesAfter / 1MB),  $timer.Elapsed.TotalSeconds)
    
    if((Test-Path -Path $zipFolder))
    {
        Write-VerboseWriter("Compress successful, removing folder.")
        Remove-Item $Folder -Force -Recurse 
    }
    if($ReturnCompressedLocation)
    {
        Set-Variable -Name compressedLocation -Value $zipFolder -Scope 1 
    }
}

Function Get-ZipFolderName {
param(
[Parameter(Mandatory=$true)][string]$Folder,
[Parameter(Mandatory=$false)][bool]$IncludeMonthDay = $false
)
    Write-VerboseWriter("Calling: Get-ZipFolderName")
    Write-VerboseWriter("Passed - [string]Folder:{0} | [bool]IncludeMonthDay:{1}" -f $Folder, $IncludeMonthDay)
    if($IncludeMonthDay)
    {
        $zipFolderNoEXT = "{0}-{1}" -f $Folder, (Get-Date -Format Md)
    }
    else 
    {
        $zipFolderNoEXT = $Folder
    }
    Write-VerboseWriter("[string]zipFolderNoEXT: {0}" -f $zipFolderNoEXT)
    $zipFolder = "{0}.zip" -f $zipFolderNoEXT
    if(Test-Path $zipFolder)
    {
        [int]$i = 1
        do{
            $zipFolder = "{0}-{1}.zip" -f $zipFolderNoEXT,$i 
            $i++
        }while(Test-Path $zipFolder)
    }
    Write-VerboseWriter("Returned: [string]zipFolder {0}" -f $zipFolder)
    return $zipFolder
}


Write-VerboseWriter("Calling: Compress-Folder")
Write-VerboseWriter("Passed - [string]Folder: {0} | [bool]IncludeDisplayZipping: {1} | [bool]ReturnCompressedLocation: {2}" -f $Folder, 
$IncludeDisplayZipping,
$ReturnCompressedLocation)

$compressedLocation = [string]::Empty
if(Test-Path $Folder)
{
    if(Confirm-IOCompression)
    {
        Compress-Now
    }
    else
    {
        if(Enable-IOCompression)
        {
            Compress-Now
        }
        else
        {
            Write-HostWriter("Unable to compress folder {0}" -f $Folder)
            Write-VerboseWriter("Unable to enable IO compression on this system")
        }
    }
}
else
{
    Write-HostWriter("Failed to find the folder {0}" -f $Folder)
}
if($ReturnCompressedLocation)
{
    Write-VerboseWriter("Returning: {0}" -f $compressedLocation)
    return $compressedLocation
}
}