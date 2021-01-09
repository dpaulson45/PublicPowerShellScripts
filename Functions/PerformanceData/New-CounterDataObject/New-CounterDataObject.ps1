Function New-CounterDataObject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I prefer New here')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '', Justification = 'See note')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$PerformanceCounterSamples
    )
    <#
    Required Functions:
        https://raw.githubusercontent.com/dpaulson45/PublicPowerShellScripts/master/Functions/PerformanceData/Get-CounterSampleToCounterObjectName/Get-CounterSampleToCounterObjectName.ps1
    #>

    Add-Type @"
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace PerformanceCounters
{
    public class CounterAccuracy
    {
        public double Percentage;
        public int SumDataPoints;
        public int EstimateDataPoints;

        public CounterAccuracy()
        {
            this.Percentage = 0;
            this.SumDataPoints = 0;
            this.EstimateDataPoints = 0;
        }
    }

    public class PerformanceCounterName
    {
        public string FullName;
        public string ServerName;
        public string ObjectName;
        public string InstanceName;
        public string CounterName;
    }

    public class CounterData : PerformanceCounterName
    {
        public CounterAccuracy Accuracy;
        public object[] AllData;
        public int GetDataCount { get { return AllData.Count() - 1;  } }
        public Hashtable TimeHash;
        public IEnumerable<object> GetData { get {return AllData.Skip(1); } }
        public object FirstSample {get {return GetData.First(); } }
        public object LastSample {get {return GetData.Last(); } }

        public CounterData()
        {
            this.Accuracy = new CounterAccuracy();
            this.TimeHash = new Hashtable();
        }
    }
}
"@

    Function Get-CounterDataObject {
        param(
            [Parameter(Mandatory = $true)][object]$PerformanceCounterSample
        )
        $counterDataObj = New-Object PerformanceCounters.CounterData
        $counterNameObj = Get-CounterSampleToCounterObjectName -PerformanceCounterSample $PerformanceCounterSample
        $counterDataObj.FullName = $counterNameObj.FullName
        $counterDataObj.ServerName = $counterNameObj.ServerName
        $counterDataObj.ObjectName = $counterNameObj.ObjectName
        $counterDataObj.InstanceName = $counterNameObj.InstanceName
        $counterDataObj.CounterName = $counterNameObj.CounterName
        return $counterDataObj
    }

    ########## Parameter Binding Exceptions ##############
    # throw [System.Management.Automation.ParameterBindingException] "Failed to provide valid ParameterName"

    $counterObj = Get-CounterDataObject -PerformanceCounterSample $PerformanceCounterSamples[0]
    $counterObj.AllData = $PerformanceCounterSamples
    foreach ($datapoint in $counterObj.GetData) {
        try {
            $counterObj.TimeHash.Add($datapoint.TimeStamp, $datapoint)
        } catch {
            #Do nothing, it appears that this sometimes happens, likely due to multiple files in the load
            #Might need to look into some debug logging to determine if this is going to be an issue or not
        }
    }

    return $counterObj
}