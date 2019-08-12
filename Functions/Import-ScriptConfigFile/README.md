# Import-ScriptConfigFile
Function that is used to read in a configuration file for all your set parameters. This allows a script to be executed with a particular set of parameters that you would like to be set each time. 

In order for this to work, the configuration needs to be setup in the similar format. 

    VariableName~VariableType~Value

If the VariableType is an array, then you need to provide additional context to properly split up the array to it's correct data type.

    ~Array=Type=SplitCharacter~ 

Examples: 
    
    ~Array=string=;~ 
    ~Array=int=,~

You can provide anything that you would like to break up the array in the last section. However, the split must be done with a '=' value. 

The main split of the data within the configuration file doesn't need to be done with ~. However, that is the default value. 