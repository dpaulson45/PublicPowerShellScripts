Function Send-Message {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$MessageFrom,
[Parameter(Mandatory=$true)][string[]]$MessageTo,
[Parameter(Mandatory=$true)][string]$MessageSubject,
[Parameter(Mandatory=$true)][string]$SMTPServer,
[Parameter(Mandatory=$false)]$Credentials,
[parameter(Mandatory=$false)]$MessageBody = " ",
[Parameter(Mandatory=$false)][string[]]$Attachments,
[Parameter(Mandatory=$false)][int]$Port = 25
)

#Function Version 1.1
$messageError = $false 
    
try
    {
    $params = @{
        To = $MessageTo
        From = $MessageFrom
        SmtpServer = $SMTPServer
        Port = $Port
        Subject = $MessageSubject
        Body = $MessageBody
    }

    if([pscredential]::Empty -ne $Credentials -and $Credentials -ne $null)
    {
        $params.Add("Credential", $Credentials)
    }
    if($Attachments -ne $null -and $Attachments.Count -gt 0)
    {
        $addAttachments = @()
        foreach($attachment in $Attachments)
        {
            if(Test-Path $attachment)
            {
                $addAttachments += $attachment
            }
        }
        if($addAttachments.Count -gt 0)
        {
            $params.Add("Attachments", $addAttachments)
        }
    }

    Send-MailMessage @params -ErrorAction stop 

}
catch
{
    Write-Host "Error occurred when trying to send the message" 
    Write-Host " "
    $displayError = $Error[0].Exception.ToString()
    Write-Warning $displayError 
    $messageError = $true 
}

return $messageError
}
    