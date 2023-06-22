<#
    Sets up Field Engineering diagnostic event logging on the DC
    https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/configure-ad-and-lds-event-logging
    Then start a network trace
    Manually stop the data collection once the issue has reproduced
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = "C:\tracing"
)

# Set the size of Directory Service event log to 250MB
$maxLogSizeKB = [Math]::Round( 250MB * .001 )
$directoryService = Get-EventLog -List | Where-Object { $_.Log -eq "Directory Service" }
$startTimeString = ([DateTime]::Now).ToString("yyyyMMddhhmmss")

try {
    New-Item $OutputDirectory -Force -ErrorAction Stop -Type Directory
} catch {
    Write-Host "Failed to create the directory for output. $_"
    exit
}

if ($directoryService.MaximumKilobytes -lt $maxLogSizeKB) {
    try {
        Limit-EventLog -LogName "Directory Service" -MaximumSize ($maxLogSizeKB * 1KB) -OverflowAction OverwriteAsNeeded -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to set the Directory Service logs to $maxLogSizeKB. Please set this manually to this value or greater and try again. $_"
        exit
    }
}

try {
    # Set the keys if they aren't already set.
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $env:COMPUTERNAME)
    $regKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\NTDS\Parameters", $true) # $true is to make it writeable

    if (-not ([string]::IsNullOrWhiteSpace($regKey))) {

        foreach ($getValue in @("Expensive Search Results Threshold", "Inefficient Search Results Threshold", "Search Time Threshold (msecs)")) {

            try {
                $resultGetValueKind = $regKey.GetValueKind($getValue)
            } catch {
                # This means it doesn't exist and is fine.
            }
            
            if ($null -ne $resultGetValueKind -and $resultGetValueKind -ne 'DWord') {
                Write-Host "Attempting to delete $getValue because it isn't the correct type."
                $regKey.DeleteValue($getValue)
            }

            $resultGetValue = $regKey.GetValue($getValue)

            if ($null -eq $resultGetValue -or
            $resultGetValue -ne 1) {
                Write-Host "Setting the $getValue to 1"
                $regKey.SetValue($getValue, 1, [Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }
    } else {
        throw "Failed to find NTDS\Parameters key"
    }

    $regKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics", $true)
    $value = "15 Field Engineering"
    $regKey.SetValue($value, 5, [Microsoft.Win32.RegistryValueKind]::DWord)
} catch {
    Write-Host "Failed to set the NTDS Registry values. $_"
    exit
}

try {
    # Create the network trace
    $networkOutput = [System.IO.Path]::Combine($OutputDirectory, "networkTrace-$($env:COMPUTERNAME)-$($startTimeString).etl")
    Write-Host "Attempting to start the network trace... " -NoNewline
    netsh trace start persistent=yes capture=yes tracefile=$networkOutput maxSize=4096

    if ($LASTEXITCODE) {
        throw "Failed to start network trace. $LastExitCode"
    }
} catch {
    Write-Host "Failed to start the network trace. $_"
}

Write-Host ""

Read-Host "Press Enter to stop the data collection after the issue has reproduced..." | Out-Null

$regKey.SetValue($value, 0, [Microsoft.Win32.RegistryValueKind]::DWord)

Copy-Item "$env:windir\System32\Winevt\Logs\Directory Service.evtx" -Destination ([System.IO.Path]::Combine($OutputDirectory, "Directory-Service-$startTimeString.evtx"))

Write-Host "Attempting to stop the network trace this can take a while."
Write-Host ""
netsh trace stop

Write-Host "Completed"
