[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][array]$Recipients,
[Parameter(Mandatory=$false)][array]$Senders,
[Parameter(Mandatory=$false)][array]$SMTPServers,
[Parameter(Mandatory=$false)][array]$MessageBodies,
[Parameter(Mandatory=$false)][array]$MessageSubjects,
[Parameter(Mandatory=$false)][string]$BaseMessageSubject,
[Parameter(Mandatory=$false)][int]$Port = 25,
[Parameter(Mandatory=$false)][int]$NumberOfMessages = 1000,
[Parameter(Mandatory=$false)][PSCredential]$Credentials
)

#Function Version 1.0
#[System.Collections.Generic.List[System.Object]]$list = New-Object -TypeName System.Collections.Generic.List[System.Object]

########################
#
# Write Functions 
#
########################

Function Write-VerboseWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($VerboseFunctionCaller -eq $null)
    {
        Write-Verbose $WriteString
    }
    else 
    {
        &$VerboseFunctionCaller $WriteString
    }
}
    
Function Write-HostWriter {
param(
[Parameter(Mandatory=$true)][string]$WriteString 
)
    if($HostFunctionCaller -eq $null)
    {
        Write-Host $WriteString
    }
    else
    {
        &$HostFunctionCaller $WriteString    
    }
}

########################
#
# Template Functions
#
########################

# Template Master: https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/Send-Message/Send-Message.ps1
Function Send-Message {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string]$MessageFrom,
[Parameter(Mandatory=$true)][string[]]$MessageTo,
[Parameter(Mandatory=$true)][string]$MessageSubject,
[Parameter(Mandatory=$true)][string]$SMTPServer,
[Parameter(Mandatory=$false)]$Credentials,
[parameter(Mandatory=$false)]$MessageBody = " ",
[Parameter(Mandatory=$false)][int]$Port = 25
)

#Function Version 1.0
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
    
# End Function Send-Message



########################
#
# End Template Functions
#
########################



Function Main {

    $random = New-Object Random 

    for($i = 0; $i -lt $NumberOfMessages; $i++)
    {
        $toIndex = $random.Next(0,$Recipients.Count)
        $fromIndex = $random.Next(0,$Senders.Count)
        $serverIndex = $random.Next(0,$SMTPServers.Count)

        $messageSubject = [string]::Empty
        $messageBody = [string]::Empty
        
        if($MessageBodies -eq $null -or $MessageBodies.Count -lt 0)
        {
            $messageBody = "Empty"
        }
        else 
        {
            $messageBody = $MessageBodies[$random.Next(0,$MessageBodies.Count)]
        }
        if($MessageSubjects -ne $null -or $MessageSubjects.Count -ge 1)
        {
            $subjectIndex = $random.Next(0,$MessageSubjects.Count)
            if(![string]::IsNullOrWhiteSpace($BaseMessageSubject))
            {
                $messageSubject = "{0} - {1}" -f $BaseMessageSubject, $MessageSubjects[$subjectIndex]
            }
            else 
            {
                $messageSubject = $MessageSubjects[$subjectIndex]
            }
        }
        else 
        {
            $messageSubject = "{0} - {1}" -f $BaseMessageSubject, $i 
        }

        if(Send-Message -MessageFrom ($Senders[$fromIndex]) -MessageTo ($Recipients[$toIndex]) -MessageSubject $messageSubject -SMTPServer ($SMTPServers[$serverIndex]) -Credentials $Credentials -MessageBody $messageBody -Port $Port)
        {
            continue
        }

        sleep 3
        
    }

}


########## Parameter Binding Exceptions ##############
# throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName" 
if($Recipients -eq $null -or $Recipients.Count -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Recipients list" 
}
if($Senders -eq $null -or $Senders.Count -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Senders list" 
}
if($SMTPServers -eq $null -or $SMTPServers.Count -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid SMTPServers list" 
}
if([string]::IsNullOrWhiteSpace($BaseMessageSubject)) #TODO, could add message subjects here as an or statement. 
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid BaseMessageSubject value" 
}
if($NumberOfMessages -lt 1)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid NumberOfMessages. Needs to be a value 1 or greater" 
}
if($Port -ne 25 -and $Port -ne 2525)
{
    throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid Port value. Must be 25 or 2525." 
}

Main