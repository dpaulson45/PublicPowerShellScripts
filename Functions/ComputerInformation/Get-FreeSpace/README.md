# Get-FreeSpace
Function that is used to be able to return the amount of GB free on a drive based off the provided file path. This works with a full drive letter location or a mapped mount point.

# Parameters 

Parameter | Description 
----------|-------------
FilePath | A full path of a location where you would like to test the amount of freespace available on that drive.

# How To Use

Use the following sample code within your script:

```

$freeSpace = Get-FreeSpace -FilePath "C:\Users\Admin\Desktop" 
if($freeSpace -gt 10)
{
    Write-Host("You have more than 10GB of Free Space on the drive.")
}
else
{
    Write-Host("You do not have more than 10GB of Free Space on the drive. You currently have {0}GB of Free Space." -f $freeSpace) 
}

```