# Get-ExchangeBuildVersionInformation
Function that is used to get the Exchange Build Information by passing the `AdminDisplayVersion` from the `Get-ExchangeServer` command. This can handle both string and the object type.

# Parameters

Parameter | Description
----------|------------
AdminDisplayVersion | Pass the object that contains the required information from `(Get-ExchangeServer ServerName).AdminDisplayVersion'

# Properties

Property | Description
---------|------------
MajorVersion | Provides a string type of what server of Exchange we are dealing with. "Exchange2010","Exchange2013","Exchange2016","Exchange2019" are all possible options here.
Major | Provides the Major build number
Minor | Provides the Minor build number
Build | Provides the Build build number
Revision | Provides the Revision build number
Product | Provides the combination of Major and Minor products as a double type
BuildRevision | Provides the combination of Build and Revision build as a double type

# How to use

Use the following sample code:

```

$buildInfo = Get-ExchangeBuildVersionInformation -AdminDisplayVersion ((Get-ExchangeServer ADT-E19A).AdminDisplayVersion)

if ($buildInfo.MajorVersion -eq "Exchange2010") {
    Write-Host "Abort i don't know how to do anything on Exchange 2010"
    exit
}

```