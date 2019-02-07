param(
[string]$BaseName="Zelda",
[int]$NumberOfUsers=100,
[int]$Padding = 2,
[int]$StartingNumber = 1,
[Parameter(Mandatory=$true)][string]$Password, 
[Parameter(Mandatory=$false)][string]$DomainName = (Get-ADDomain -Current LocalComputer).DNSRoot,
[Parameter(Mandatory=$false)][Array]$MailboxDatabases,
[Parameter(Mandatory=$false)][string]$OrganizationalUnit
)

$securepassword = (ConvertTo-SecureString -AsPlainText -String $Password -Force)
#RandomObject 
$randobj = New-Object System.Random

Function Get-RandomDatabase()
{
    $mbd = $null
    $index = $randobj.Next(0,$MailboxDatabases.Count)
    $mbd = $MailboxDatabases[$index]
    return $mbd
}

Function Main 
{
   
    for($i = 1; $i -le $NumberOfUsers; $i++)
    {
        $UserName = "{0}{1}" -f $BaseName, $StartingNumber.ToString().PadLeft($Padding,"0")
        $StartingNumber++
        $upn = $UserName + "@" + $DomainName
        $db = $null
        if($MailboxDatabases.Count -gt 0)
        {
            $db = Get-RandomDatabase
        }
        $params = @{
        Name = $UserName
        UserPrincipalName = $upn
        SamAccountName = $UserName
        Password = $securepassword 
        ResetPasswordOnNextLogon = $false 
        }
        if($db -ne $null)
        {
            $params.Add("Database", $db)
        }
        if($OrganizationalUnit -ne $null -and $OrganizationalUnit -ne [string]::Empty)
        {
            $params.Add("OrganizationalUnit", $OrganizationalUnit)
        }
        New-Mailbox @params
    }

}

Main 