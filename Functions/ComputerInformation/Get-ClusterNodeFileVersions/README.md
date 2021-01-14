# Get-ClusterNodeFileVersions
Function that is used to get the local servers cluster DLLs and exe files version information and provide them back.

# Parameters 

Parameter | Description
----------|------------
ClusterDirectory | The cluster directory that contains all the binary information. Default value `C:\Windows\Cluster`

# Properties 

Property | Description
---------|------------
ComputerName | Provides the computer name that this was run on
Files | All files in the `ClusterDirectory` and their build information based off the File Item Properties

## File Item Properties

Property | Description
---------|------------
FileName | The name of the file
FileMajorPart | The VersionInfo.FileMajorPart
FileMinorPart | The VersionInfo.FileMinorPart
FileBuildPart | The VersionInfo.FileBuildPart
FilePrivatePart | The VersionInfo.FilePrivatePart
ProductVersion | The VersionInfo.ProductVersion
LastWriteTime | The LastWriteTimeUtc

# How To Use

Use the following sample code within your script: 

```

$clusterFilesLocal = Get-ClusterNodeFilesVersions

$clusterFilesRemote = Invoke-Command -ComputerName "RemoteServer" -ScriptBlock ${Function:Get-ClusterNodeFilesVersions}

foreach ($key in $clusterFilesLocal.Files.Keys) {

    $local = $clusterFilesLocal.Files[$key]
    $remote = $clusterFilesRemote.Files[$key]

    if ($local.ProductVersion -ne $remote.ProductVersion) {
        Write-Host "Cluster nodes mismatch!" 
    }
}

```