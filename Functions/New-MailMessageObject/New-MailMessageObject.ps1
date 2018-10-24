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