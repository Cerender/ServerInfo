<#------------------------------------------------------------------------------
    Jason McClary
    mcclarj@mail.amc.edu
    28 Mar 2016
    
    Description:
    Gather Server info into a CSV
    
    Arguments:
    If blank script runs against local computer
    Multiple computer names can be passed as a list separated by spaces:
        ServerInfo.ps1 computer1 computer2 anotherComputer
    A text file with a list of computer names can also be passed
        ServerInfo.ps1 comp.txt
        
    Tasks:
    - Create a file that lists:
        - Operating System
        - Windows Version
        - RAM (in GB)
        - Model
        - Processor
        - Device ID
        - Volume Name
        - Drive Size (in GB)
        - Free Space (in GB)



--------------------------------------------------------------------------------
                                CONSTANTS
------------------------------------------------------------------------------#>
#Date/ Time Stamp
$dtStamp = Get-Date -UFormat "%Y%b%d"    #http://ss64.com/bash/date.html#format

set-variable logOutput -option Constant -value "Servers_$dtStamp.csv"

<#------------------------------------------------------------------------------
                                FUNCTIONS
------------------------------------------------------------------------------#>
function SendOutput{
    param (
        [string]$TextOut,
        [string]$mode
    )
    Process{
        switch ($mode){
            screen {"$TextOut"}
            new {$TextOut | Out-file -filepath $logOutput -Encoding utf8}
            default {$TextOut | Out-file -append -filepath $logOutput -Encoding utf8}
        }
    }
}
    
<#------------------------------------------------------------------------------
                                    MAIN
------------------------------------------------------------------------------#>

## Format arguments from none, list or text file 
IF (!$args){
    $compNames = $env:computername # Get the local computer name
} ELSE {
    $passFile = Test-Path $args

    IF ($passFile -eq $True) {
        $compNames = get-content $args
    } ELSE {
        $compNames = $args
    }
}

# Create header
SendOutput -mode new -TextOut "Server,Operating System,Windows Version,RAM (Gigabytes),Model,Processor Model,Number of Processors,Device ID,Volume Name,Size,Free Space"

# Loop through all computers
FOREACH ($compName in $compNames) {
    # Initialize Variables
    $objOS =""
    $objCS =""
    $RAM =""
    $objProcs =""
    $procCount =""
    $objDisks =""
    $driveSizeGB =""
    $driveFreeGB =""
    
    
    IF(Test-Connection -count 1 -quiet $compName){                         # Check for valid connection to computer

        $objOS = Get-WMIObject -class Win32_OperatingSystem -computername $compName -Property "Caption","Version"
        $objCS = Get-WMIObject -class Win32_ComputerSystem -computername $compName -Property "Model","TotalPhysicalMemory"
        $RAM = [math]::Round(($objCS.TotalPhysicalMemory/(1024*1024*1024)),1) # Convert to Gigabytes of RAM and round to 1 decimal place
        
        $objProcs = Get-WMIObject -class Win32_Processor -computername $compName -Property "Name","NumberOfLogicalProcessors"
        $procCount = $objProcs.length
        IF (!$procCount){               # If there is only 1 processor the length of the array is NULL
            $procCount = $objProcs.NumberOfLogicalProcessors
            $procName = $objProcs.Name
        } ELSE {
            $procCount = $procCount * $objProcs[0].NumberOfLogicalProcessors
            $procName = $objProcs[0].Name
        }
        
        $objDisks = Get-WMIObject -class Win32_LogicalDisk -computername $compName -Property "DriveType","DeviceID","VolumeName","Size","FreeSpace"
        
        $i = 0
        FOREACH ($drive in $objDisks){
            IF ($drive.DriveType -eq "3"){      # Only return Local Disks (Device ID 3)
                $i++
                $driveSizeGB = [math]::Round(($drive.Size/(1024*1024*1024)),0)
                $driveFreeGB = [math]::Round(($drive.FreeSpace/(1024*1024*1024)),0)
                IF ($i -eq 1){
                    SendOutput -TextOut "$compName,$($objOS.Caption),$($objOS.Version),$RAM GB,$($objCS.Model),$procName,$procCount,$($drive.DeviceID),$($drive.VolumeName),$driveSizeGB GB,$driveFreeGB GB"
                } ELSE {
                    SendOutput -TextOut ",,,,,,,$($drive.DeviceID),$($drive.VolumeName),$driveSizeGB GB,$driveFreeGB GB"
                }
            }
        }
        "$compName complete!"
        
    } ELSE { # If no connection- log to file
        "$compName    **** Could not connect ****"
        SendOutput -TextOut "$compName,Could not connect"
    }    
}