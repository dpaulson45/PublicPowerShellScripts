# Enter-YesNoLoopAction
Function that is used to check to loop you through a question waiting for a 'y' or 'n' response and take action on it based off the function that is passed to it. 

# Parameters

Parameter | Description 
----------|------------
Question | The question that you wish to ask over and over again till a valid option is provided. ('y' or a 'n')
YesAction | The action that you wish to take if the answer is 'y'
NoAction | The action that you wish to take if the answer is 'n'

# How To Use

Use the following sample code within your script: 

```
#Example 1: 
if(Enter-YesNoLoopAction -Question "Is the sky blue?" -YesAction {return $true} -NoAction {return $false})
{
    #Do something if 'y' is returned
}
else
{
    #Do something different if 'n' is returned
}

...........
#Example 2: 
Enter-YesNoLoopAction -Question "Do you wish to continue?" -YesAction {} -NoAction {exit} 
#Continue with the script actions 

```