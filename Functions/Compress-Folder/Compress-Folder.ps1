[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$Folder,
[Parameter(Mandatory=$false)][bool]$IncludeMonthDay = $false
)

Function Enable-IOCompression
{
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    $successful = $true 
    try 
    {
        Add-Type -AssemblyName System.IO.Compression.Filesystem 
    }
    catch 
    {
        Write-Host("[{0}] : Failed to load .NET Compression assembly. Unable to zip up the data." -f $env:COMPUTERNAME)
        $successful = $false 
    }
    finally 
    {
        $ErrorActionPreference = $oldErrorAction
    }
    return $successful
}
Function Confirm-IOCompression 
{
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
    return $successful
}

Function Compress-Now
{
    $zipFolder = Get-ZipFolderName -Folder $Folder -IncludeMonthDay $IncludeMonthDay
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Folder, $zipFolder)
    if((Test-Path -Path $zipFolder))
    {
        Remove-Item $Folder -Force -Recurse 
    }
}

Function Get-ZipFolderName {
param(
[Parameter(Mandatory=$true)][string]$Folder,
[Parameter(Mandatory=$false)][bool]$IncludeMonthDay = $false
)
    if($IncludeMonthDay)
    {
        $zipFolderNoEXT = "{0}-{1}" -f $Folder, (Get-Date -Format Md)
    }
    else 
    {
        $zipFolderNoEXT = $Folder
    }

    $zipFolder = "{0}.zip" -f $zipFolderNoEXT
    if(Test-Path $zipFolder)
    {
        [int]$i = 1
        do{
            $zipFolder = "{0}-{1}.zip" -f $zipFolderNoEXT,$i 
            $i++
        }while(Test-Path $zipFolder)
    }
    return $zipFolder
}

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
        Write-Host("Unable to compress folder {0}" -f $Folder)
    }
}