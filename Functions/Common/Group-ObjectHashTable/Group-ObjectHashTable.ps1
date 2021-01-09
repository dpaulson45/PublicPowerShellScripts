Function Group-ObjectHashTable {
    param
    (
        [string[]]
        $Property
    )

    #Found from: http://powershell.one/tricks/performance/group-object
    begin {
        # create an empty hashtable
        $hashtable = @{}
    }

    process {
        # create a key based on the submitted properties, and turn
        # it into a string
        $key = $(foreach ($prop in $Property) { $_.$prop }) -join ','

        # check to see if the key is present already
        if ($hashtable.ContainsKey($key) -eq $false) {
            # add an empty array list
            $hashtable[$key] = [Collections.Arraylist]@()
        }

        # add element to appropriate array list:
        $null = $hashtable[$key].Add($_)
    }

    end {
        # return the entire hashtable:
        $hashtable
    }
}