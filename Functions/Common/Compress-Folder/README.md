# Compress-Folder
Function that is used to be able to zip up a folder that you would like in that location. It automatically loads up the .NET System.IO.Compression.Filesystem assembly if it isn't detected to be loaded in order to compress the files. If we aren't able to load this assembly, we don't attempt to zip up the files. 

# Paramters 

Parameter | Description 
----------|------------
Folder | Is the full path name to the directory that you wish to zip up. 
IncludeMonthDay | Will append the Month and Day to the folder name. "Data-1220.zip". Default: $false.
IncludeDisplayZipping | Will write to host that we are currently zipping up the Folder. Default: $true.
ReturnCompressedLocation | Will return a string value of where we zipped up the data to. Default: $false. 

# How To Use

Use the following sample code with your script: 

```
#Example 1: 
$folder = "C:\Users\Admin\Desktop" 
Compress-Folder -Folder $folder -IncludeMonthDay $true

#Example 2: 
$folder = "C:\Users\Admin\Desktop" 
$returnLocation = $true
$compressedFolderLocation = Compress-Folder -Folder $folder -ReturnCompressedLocation $returnLocation

if($returnLocation -and 
    (!([string]::IsNullOrEmpty($compressedFolderLocation))))
{
    #Some Action
}

```