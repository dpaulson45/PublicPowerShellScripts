# Save-DataToFile
Function that is used to save out data to a location. You can have it save it out as a text file and/or xml file format. 

# Parameters

Parameter | Description 
----------|------------
DataIn | Is the data object that you wish to save out to a file. 
SaveToLocation | The full path to the file that you would like to save the data out to, besides the extention of the file name. (Example: C:\Users\Admin\Desktop\MyFile)
FormatList | When both SaveTextFile and FormatList is set to true, will export the data out to a text file using Format-List. Otherwise, if it is set to false, will use Format-Table. Default: True 
SaveTextFile | When this is set to true, we will export the data to a text file using either Format-Table or Format-List. Default: True. 
SaveXMLFile | When this is set to true, we will export the data to xml via Export-Clixml. Default: true 

# How To Use 

Use the following sample code within your script: 

```
$volumes = Get-Volume 

Save-DataToFile -DataIn $volumes -SaveToLocation "C:\Users\Admin\Desktop\Volumes" 

```