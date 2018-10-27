[CmdletBinding()]
param(

)


#############################
#
# Template Functions 
#
#############################


# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-MailMessageObject/New-MailMessageObject.ps1
Function New-MailMessageObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$SMTPSender,
[Parameter(Mandatory=$true)][array]$SMTPRecipients,
[Parameter(Mandatory=$true)][string]$SMTPServerNameOrIPAddress,
[Parameter(Mandatory=$true)][string]$MessageSubject,
[Parameter(Mandatory=$false)][string]$MessageBody,
[Parameter(Mandatory=$false)][PSCredential]$Credentials,
[Parameter(Mandatory=$false)][int]$Port = 25,
[Parameter(Mandatory=$false)][string]$CustomTestMessageSubject = "Script Mail Message Object Test",
[Parameter(Mandatory=$false)][string]$CustomTestMessageBody = "Test Worked!"
)
#Function Version 1.0
if([string]::IsNullOrWhiteSpace($CustomTestMessageSubject))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageSubject"
}
if([string]::IsNullOrWhiteSpace($CustomTestMessageBody))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid CustomTestMessageBody"
}

$params = @{
    To = $SMTPRecipients
    From = $SMTPSender
    SmtpServer = $SMTPServerNameOrIPAddress
    Port = $Port
    Subject = $CustomTestMessageSubject
    Body = $CustomTestMessageBody
}
[bool]$passedCreds = $false 
if([pscredential]::Empty -ne $Credentials -and $Credentials -ne $null)
{
    $passedCreds = $true 
    $params.Add("Credential", $Credentials)
}

try 
{
    Send-MailMessage @params -ErrorAction Stop
}
catch 
{
    throw
}

#Passed sending the message, going to build the object 
$params["Subject"] = $MessageSubject
if([string]::IsNullOrWhiteSpace($MessageBody))
{
    $params.Remove("Body")
}
else 
{
    $params["Body"] = $MessageBody
}


$mailObject = New-Object -TypeName pscustomobject 
$mailObject | Add-Member -MemberType NoteProperty -Name "Parameters" -Value $params
$mailObject | Add-Member -MemberType NoteProperty -Name "Exception" -Value ([string]::Empty)
$mailObject | Add-Member -MemberType NoteProperty -Name "Success" -Value $true 

$mailObject | Add-Member -MemberType ScriptMethod -Name "SendMail" -Value {

    $params = $this.Parameters 
    try 
    {
        Send-MailMessage @params 
    }
    catch 
    {
        $this.Success = $false 
        $this.Exception = $Error[0].Exception
    }
    
} 

$mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageBody" -Value {
    param(
    [string]$Body
    )
    [hashtable]$params = $this.Parameters
    $bodyNullEmpty = $false 
    if([string]::IsNullOrWhiteSpace($Body))
    {
        $bodyNullEmpty = $true  
    }
    if($params.ContainsKey("Body"))
    {
        if($bodyNullEmpty)
        {
            $params.Remove("Body") 
        }
        else 
        {
            $params["Body"] = $Body
        }
    }
    else 
    {
        if($bodyNullEmpty)
        {
            return 
        }
        $params.Add("Body", $Body)     
    }
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "UpdateMessageSubject" -Value {
    param(
    [string]$MessageSubject
    )
    if([string]::IsNullOrWhiteSpace($MessageSubject))
    {
        throw [System.Management.Automation.ParameterBindingException] "Failed to provide MessageSubject"
    }
    $params = $this.Parameters 
    $params["Subject"] = $MessageSubject
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "GetMessageSuccess" -Value {
    return $this.Success 
}

$mailObject | Add-Member -MemberType ScriptMethod -Name "GetExceptionReason" -Value {
    return $this.Exception
}

return $mailObject 
}
# End Function New-MailMessageObject




# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/New-StorportLogmanObject/New-StorportLogmanObject.ps1
Function New-StorportLogmanObject {
[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string]$LogmanName = "storport",
[Parameter(Mandatory=$false)][string]$SaveName,
[Parameter(Mandatory=$false)][int]$EtlFileSize = 4096,
[Parameter(Mandatory=$false)][string]$SavePath = "C:\Traces",
[Parameter(Mandatory=$false)][string]$Provider = "Microsoft-Windows-StorPort",
[Parameter(Mandatory=$false)][string]$AppendVersioningToFile = "mmddhhmm",
[Parameter(Mandatory=$false)][array]$ServerList,
[Parameter(Mandatory=$false)][string]$KeywordsAny = "0xffffffffffffffff",
[Parameter(Mandatory=$false)][string]$Level = "0xff",
[Parameter(Mandatory=$false)][int]$MinimumBuffer = 16, #Note this appears to have a max min value of 20 on newer systems but still works 
[Parameter(Mandatory=$false)][int]$MaximumBuffer = 16, 
[Parameter(Mandatory=$false)][int]$BufferSizeKB = 1024, #default is actually 8KB 
[Parameter(Mandatory=$false)][string]$LogFormat = "bincirc"
)

#Following this blog: https://blogs.technet.microsoft.com/askcore/2013/04/25/tracing-with-storport-in-windows-2012-and-windows-8-with-kb2819476-hotfix/
#Function Version 1.0
if([string]::IsNullOrEmpty($LogmanName.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogmanName" 
}
if($EtlFileSize -lt 100 -or $EtlFileSize -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid EtlFileSize. Use a value between 100 and 1000"
}
if([string]::IsNullOrEmpty($SavePath.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SavePath" 
}
if([string]::IsNullOrEmpty($Provider.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Provider" 
}
if([string]::IsNullOrEmpty($AppendVersioningToFile.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid AppendVersioningToFile"
}
if($ServerList -eq $null -or $ServerList.Count -eq 0)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ServerList"
}
if([string]::IsNullOrEmpty($KeywordsAny.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid KeywordsAny" 
}
if([string]::IsNullOrEmpty($Level.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Level" 
}
if($MinimumBuffer -lt 10 -or $MinimumBuffer -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MinimumBuffer. Use a value between 10 and 1000"
}
if($MaximumBuffer -lt 10 -or $MaximumBuffer -gt 1000)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid MaximumBuffer. Use a value between 10 and 1000"
}
if($BufferSizeKB -lt 8 -or $BufferSizeKB -gt 4096)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BufferSizeKB. Use a value between 8 and 4096"
}
if([string]::IsNullOrEmpty($LogFormat.Trim()))
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid LogFormat" 
}
if([string]::IsNullOrEmpty($SaveName.Trim()))
{
    $SaveName = $LogmanName
}

Add-Type -TypeDefinition @"
    namespace StorportLogman
    {
        public enum StatusCode
        {
            None,
            Success,
            SingleServerFailure,
            Failed
        }
    }

"@ 


Function New-ServersStatusObject {

    $hasher = @{}
    foreach($server in $ServerList)
    {
        $statusObject = New-Object pscustomobject
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "CreateStartStatusCode" -Value ([ExtraLogman.StatusCode]::None)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedResults" -Value ([string]::Empty)
        $statusObject | Add-Member -MemberType NoteProperty -Name "StoppedStatusCode" -Value ([ExtraLogman.StatusCode]::None)

        $hasher.Add($server,$statusObject)
    }
    return $hasher
}

$logmanObject = New-Object pscustomobject 

$logmanObject | Add-Member -MemberType NoteProperty -Name "TraceName" -Value $LogmanName
$logmanObject | Add-Member -MemberType NoteProperty -Name "ETLFileSize" -Value $EtlFileSize
$logmanObject | Add-Member -MemberType NoteProperty -Name "Provider" -Value $Provider
$logmanObject | Add-Member -MemberType NoteProperty -Name "AppendVersion" -Value $AppendVersioningToFile
$logmanObject | Add-Member -MemberType NoteProperty -Name "FileDirectory" -Value $SavePath
$logmanObject | Add-Member -MemberType NoteProperty -Name "FileName" -Value $SaveName
$logmanObject | Add-Member -MemberType NoteProperty -Name "Servers" -Value $ServerList
$logmanObject | Add-Member -MemberType NoteProperty -Name "ServersStatus" -Value (New-ServersStatusObject)
$logmanObject | Add-Member -MemberType NoteProperty -Name "KeywordsAny" -Value $KeywordsAny
$logmanObject | Add-Member -MemberType NoteProperty -Name "Level" -Value $Level
$logmanObject | Add-Member -MemberType NoteProperty -Name "MinimumBuffer" -Value $MinimumBuffer
$logmanObject | Add-Member -MemberType NoteProperty -Name "MaximumBuffer" -Value $MaximumBuffer
$logmanObject | Add-Member -MemberType NoteProperty -Name "BufferSizeKB" -Value $BufferSizeKB
$logmanObject | Add-Member -MemberType NoteProperty -Name "LogFormat" -Value $LogFormat

$logmanObject | Add-Member -MemberType ScriptMethod -Name "CreateAndStartTrace" -Value {

    $servers = $this.Servers 
    $path = $this.FileDirectory
    $fileName = $this.FileName
    $maxSize = $this.EtlFileSize
    $logman = $this.TraceName
    $appendVersion = $this.AppendVersion
    $provider = $this.Provider
    $keywordsAny = $this.KeywordsAny
    $level = $this.Level
    $minimumBuffer = $this.MinimumBuffer
    $maximumBuffer = $this.MaximumBuffer
    $bufferSizeKB = $this.BufferSizeKB
    $logFormat = $this.LogFormat
    $failedCount = 0 
    foreach($server in $servers)
    {
        $fullFileName = "{0}\{1}_{2}.etl" -f $path, $fileName, $server
        [array]$results = logman create trace $logman -o $fullFileName -p $provider $keywordsAny $level -nb $minimumBuffer $maximumBuffer -bs $bufferSizeKB -f $logFormat -max $maxSize -s $server -ets 
        $this.ServersStatus[$server].CreateStartResults = $results
        if($results[-1].Trim() -eq "The command completed successfully.")
        {
            $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].CreateStartStatusCode = [StorportLogman.StatusCode]::Failed
            $failedCount++
        }
    }
    switch($failedCount)
    {
        0{return [StorportLogman.StatusCode]::Success}
        {(-eq $servers.Count)}{return [StorportLogman.StatusCode]::Failed}
        default {return [StorportLogman.StatusCode]::SingleServerFailure}
    }

}

$logmanObject | Add-Member -MemberType ScriptMethod -Name "StopLogman" -Value {
    
    $servers = $this.Servers 
    $logman = $this.TraceName
    $failureCount = 0 
    foreach($server in $servers)
    {
        [array]$results = logman stop $logman -s $server -ets 
        $this.ServersStatus[$server].StoppedResults = $results
        if(($results[-1].Trim()) -eq"The command completed successfully.")
        {
            $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Success
        }
        else 
        {
            $this.ServersStatus[$server].StoppedStatusCode = [StorportLogman.StatusCode]::Failed
            $failureCount++
        }
    }

    switch($failureCount)
    {
        0{return [StorportLogman.StatusCode]::Success}
        {($failureCount -eq $servers.Count)}{return [StorportLogman.StatusCode]::Failed}
        default {return [StorportLogman.StatusCode]::SingleServerFailure}
    }
}

return $logmanObject
}
# End Function New-StorportLogmanObject







#############################
#
# End Template Functions 
#
#############################
