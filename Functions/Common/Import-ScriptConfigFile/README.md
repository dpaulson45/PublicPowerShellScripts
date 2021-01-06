# Import-ScriptConfigFile
Function that is used to read in a configuration file for all your set parameters. This allows a script to be executed with a particular set of parameters that you would like to be set each time. 

In order for this to work, the configuration needs to be setup in the similar format. 

    VariableName~VariableType~Value

Valid VariableType is the following: 

* GetContent
* Array
* Bool 
* Int
* double
* int64

If the VariableType is GetContent provide the path to the file that you wish to do Get-Content against. We will store that value as the variable. This is recommended for large string/array types. Example a very large Performance Data Collector Set.

If the VariableType is an array, then you need to provide additional context to properly split up the array to it's correct data type.

    ~Array=Type=SplitCharacter~ 

Examples: 
    
    ~Array=string=;~ 
    ~Array=int=,~

You can provide anything that you would like to break up the array in the last section. However, the split must be done with a '=' value. 

The main split of the data within the configuration file doesn't need to be done with ~. However, that is the default value. 

# How To Use 

Use the following sample code within your script:

```
$scriptConfig = "{0}\{1}.config" -f (Split-Path -Parent $MyInvocation.MyCommand.Path), (Split-Path -Leaf $MyInvocation.MyCommand.Path)

if(Test-Path $scriptConfig)
{
    Import-ScriptConfigFile -ScriptConfigFileLocation $scriptConfig 
}

```

Here is how you can setup your .config file.

```
ExtraTraceConfigFileContent~Array=string=;~TraceLevels:Debug,Warning,Error,Fatal,Info,Performance,Function,Pfd;ManagedStore.MapiDisp:RpcBuffer,RpcOperation,RpcDetail,RpcContextPool;
EnableEmailNotification~bool~true
SMTPSender~string~david@adt.local
NetshTraceMaxSize~int~2048
ClientPerformanceDataCollectionSetCounters~GetContent~.\ClientPerformanceDataCollectionSetCounters.config
```