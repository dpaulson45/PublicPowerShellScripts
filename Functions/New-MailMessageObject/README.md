# New-MailMessageObject
Function that is used to create an object for you to be able to send a mail message. This is useful for a script design of monitoring for an issue and to get an easy notification. 

# Paramters

Parameter | Description 
----------|------------
SMTPSender | The sender that we are sending the message as. This only needs to match a valid user in the environment if the SMTP server doesn't allow anonymous messages to be sent to it's receive connector. 
SMTPRecipients | The list of SMTP addresses that you wish to send the message to. 
SMTPServerNameOrIPAddress | The SMTP server that we are going to submit the message to.
MessageSubject | The Message Subject that we are sending. 
MessageBody | The Body of the Message that we are sending. 
Credentials | Pass the credentials if anonymous isn't allowed.
Port | The port that you wish to send messages to. Default Port 25.
CustomTestMessageSubject | Custom Subject Message to validate the configuration before returning the mail message object. Default "Script Mail Message Object Test"
CustomTestMessageBody | Custom Body to the Message to validate the configuration before returning the mail message object. Default "Test Worked!"

# Methods

Method | Description 
-------|------------
SendMail() | Executes a send of the message with the current set message properties on the message.
UpdateMessageBodyTypeArray() | Updates the body of the message parameter, when the passed value type is an array type to break it up correctly. 
UpdateMessageBody() | Updates the body of the message parameter, when the passed value type is a string. 
UpdateMessageSubject() | Updates the subject of the message parameter. 
UpdateMessageSmtpServer() | Updates the SMTP Server that we wish to send the message to. 
GetMessageSmtpServer() | Provides the current value of the SMTP Server that we are attempting to send to. 
GetExceptionReason() | Provides the Exception Reason that we failed to send the message. 

# How To Use

Use the following example code to use this Mail Message Object within a script: 

```
$params = @{
    SMTPSender = "david@contoso.local" 
    SMTPRecipients = "ExchangeAdmins@contoso.local" 
    SMTPServerNameOrIPAddress = "192.168.0.1"
    MessageSubject = "Exchange Server Is Down" 
}

try 
{
    $Script:mailMessage = New-MailMessageObject @params
}
catch 
{
    Write-Host("Failed to send the mail message: {0}" -f ($Script:mailMessage.GetExceptionReason()))
    #handle it here
}

...
$Script:mailMessage.UpdateMessageBody("An Issue has occurred at: {0}" -f [DateTime]::Now)
$Script:mailMessage.SendMail()
...

```