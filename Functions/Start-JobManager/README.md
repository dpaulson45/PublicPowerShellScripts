# Start-JobManager
Function that is used to be able to pass of a script block with a list of servers to execute them with Invoke-Command as a job. This improves the time it takes to loop through some possible long running tasks on multiple servers at once vs one server at a time.

This is extremely useful for when you can't do all the servers at once with Invoke-Command normally if you are passing large objects. This way you can chuck up what you are sending and not run into a sizing issue. 