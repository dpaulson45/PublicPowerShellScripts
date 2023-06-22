<# 
    This script is to create Exchange Debug Tracing, LDAP Client Tracing, and Networking
    We need setup all the tracing requirements
    You hit enter manually to stop the data collection
#>
param(
    [string]$OutputDirectory = "C:\tracing"
)

#Constants
$extraName = "ExchangeDebugTraces"
$ldapName = "ds_ds"
$startTimeString = ([DateTime]::Now).ToString("yyyyMMddhhmmss")

try {

    # Create the extra and start it
    $extraConfigContent = @("TraceLevels:Debug,Warning,Error,Fatal,Info,Performance,Function,Pfd
ADProvider:ADFind,ADObject,ADPropertyRequest,ADRead,ADReadDetails,LdapFilterBuilder
MessagingPolicies:Journaling,RulesEngine,TransportRulesEngine
Transport:JournalingRulesCache,TransportRulesCache
FilteredTracing:No
InMemoryTracing:No")

    $extraConfigContent | Out-File C:\EnabledTraces.config -Force -ErrorAction Stop -Encoding ascii
    Write-Host "Created the EnabledTraces.config file"
    logman $extraName | Out-Null

    if (-not ($LASTEXITCODE)) {
        # Found something, must delete it
        Write-Host "Attempting to stop the current $extraName... " -NoNewline
        logman $extraName stop
        Write-Host "Attempting to delete the current $extraName... " -NoNewline
        logman $extraName delete
    }

    $extraOutput = [System.IO.Path]::Combine($OutputDirectory, "extra-$($env:COMPUTERNAME)-$($startTimeString).etl")

    Write-Host "Attempting to create $extraName... " -NoNewline
    logman create trace $extraName -p "{79bb49e6-2a2c-46e4-9167-fa122525d540}" -o $extraOutput -ow -f bincirc -max 2048 -mode globalsequence

    if ($LASTEXITCODE) {
        throw "Failed to create the Exchange Debug Trace. $LastExitCode"
    }

    Write-Host "Attempting to start $extraName... " -NoNewline
    logman $extraName start

    if ($LASTEXITCODE) {
        throw "Failed to start the Exchange Debug Trace. $LastExitCode"
    }
}
catch {
    Write-Host "Failed to setup and start Exchange Debug Tracing. $_"
    exit
}

try {
    # Create and start LDAP Client Tracing
    # https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/turn-on-debug-logging-ldap-client
    $ldapSubKey = "System\CurrentControlSet\Services\ldap\Tracing\EdgeTransport.exe"
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $env:COMPUTERNAME)
    $regKey = $reg.OpenSubKey($ldapSubKey)

    if ($null -eq $regKey) {
        # Create the key
        $reg.CreateSubKey($ldapSubKey)
    }

    # Make sure it isn't already started.
    logman $ldapName -ets | Out-Null

    if (-not ($LASTEXITCODE)) {
        Write-Host "Attempting to stop the current $ldapName... " -NoNewline
        logman stop $ldapName -ets
    }

    $ldapOutput = [System.IO.Path]::Combine($OutputDirectory, "ldap-$($env:COMPUTERNAME)-$($startTimeString).etl")

    Write-Host "Attempting to create and start the current $ldapName... " -NoNewline
    logman create trace $ldapName -ow -o $ldapOutput -p "Microsoft-Windows-LDAP-Client" 0x1a59afa3 0xff -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 4096 -ets

    if ($LASTEXITCODE) {
        throw "Failed to start LDAP client tracing"
    }

}
catch {
    Write-Host "Failed to setup and start LDAP Client Tracing. $_"
    exit
}

try {
    # Start the Network trace
    $networkOutput = [System.IO.Path]::Combine($OutputDirectory, "networkTrace-$($env:COMPUTERNAME)-$($startTimeString).etl")
    Write-Host "Attempting to start the network trace... " -NoNewline
    netsh trace start persistent=yes capture=yes tracefile=$networkOutput maxSize=4096

    if ($LASTEXITCODE) {
        throw "Failed to start network trace. $LastExitCode"
    }
}
catch {
    Write-Host "Failed to setup and start network trace. $_"
    exit
}

Write-Host ""

Read-Host "Press Enter to stop the data collection after the issue has reproduced..." | Out-Null

# issue has occurred stop the data collection now
Write-Host "Stopping $extraName... " -NoNewline
logman stop $extraName
Write-Host "Stopping $ldapName... " -NoNewline
logman stop $ldapName -ets
Write-Host "Attempting to stop the network trace this can take a while."
Write-Host ""
netsh trace stop

# Convert the LDAP Client Tracing
$ldapConvertOutput = $ldapOutput.Replace(".etl", "-LDAP_CLIENT-formatted.txt")
netsh trace convert input=$ldapOutput output=$ldapConvertOutput

Write-Host "Completed"
