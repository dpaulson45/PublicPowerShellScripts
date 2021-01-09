Function Send-Message {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'I prefer write host')]
    [CmdletBinding()]
    [OutputType("System.Boolean")]
    param(
        [Parameter(Mandatory = $true)][string]$MessageFrom,
        [Parameter(Mandatory = $true)][string[]]$MessageTo,
        [Parameter(Mandatory = $true)][string]$MessageSubject,
        [Parameter(Mandatory = $true)][string]$SMTPServer,
        [Parameter(Mandatory = $false)][PSCredential]$Credentials,
        [parameter(Mandatory = $false)]$MessageBody = " ",
        [Parameter(Mandatory = $false)][string[]]$Attachments,
        [Parameter(Mandatory = $false)][int]$Port = 25
    )

    $messageError = $false

    try {
        $params = @{
            To         = $MessageTo
            From       = $MessageFrom
            SmtpServer = $SMTPServer
            Port       = $Port
            Subject    = $MessageSubject
            Body       = $MessageBody
        }

        if ([PSCredential]::Empty -ne $Credentials -and
            $null -ne $Credentials) {
            $params.Add("Credential", $Credentials)
        }
        if ($null -ne $Attachments -and
            $Attachments.Count -gt 0) {
            $addAttachments = @()
            foreach ($attachment in $Attachments) {
                if (Test-Path $attachment) {
                    $addAttachments += $attachment
                }
            }
            if ($addAttachments.Count -gt 0) {
                $params.Add("Attachments", $addAttachments)
            }
        }

        Send-MailMessage @params -ErrorAction stop
    } catch {
        Write-Host "Error occurred when trying to send the message"
        Write-Host " "
        $displayError = $Error[0].Exception.ToString()
        Write-Warning $displayError
        $messageError = $true
    }

    return $messageError
}