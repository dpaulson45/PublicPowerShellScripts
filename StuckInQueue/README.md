# Mail Stuck in submission queue with 4004 event

Was seeing a lot of case come up regarding message stuck in the submission queue and seeing a 4004 event in the application logs. Turns out we aren't getting the attribute `msExchTransportRuleXml` from the DC in an LDAP call. We need to collect data during the repro time from both sides to understand more where the issue might be at for the layer. This isn't doesn't reproduce 100% of the time and the attribute is on the object and has been for years. Thus leading to something is manipulating the data and we need to track it down.


# DcLdapNetworkTracing

This script is used to collect the data needed from the DC to assist with troubleshooting this problem. We setup field engineering diagnostic data to be collected as well as a network trace to conclude if the payload was altered at all.

https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/configure-ad-and-lds-event-logging

### Example

This will run the script by default. It will collect the data needed to the `c:\tracing` directory on the server.

```
.\DcLdapNetworkTracing.ps1
```

This will change the output location to the `d:\logs` location.

```
.\DcLdapNetworkTracing.ps1 -OutputDirectory d:\logs
```

# ExtraNetworkLdapClientTracing

This script is used to collect the data needed from the Exchange Server. This includes our Exchange Debug Tracing, LDAP Client Tracing, and Network tracing to see if the payload was altered on the client in comparison to the DC.

### Example

This will run the script by default. It will collect the data needed to the `c:\tracing` directory on the server.

```
.\ExtraNetworkLdapClientTracing.ps1
```

This will change the output location to the `d:\logs` location.

```
.\ExtraNetworkLdapClientTracing.ps1 -OutputDirectory d:\logs
```
