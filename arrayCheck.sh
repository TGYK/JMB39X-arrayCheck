#!/bin/bash
#Credits: TGYK

#Script to use smartmontools to iterate over each disk in an array
#behind a JMB39X SATA RAID/Port multiplier and report a very brief
#health status. This script takes two configuration arguments: The
#device as located within /dev, and the number of disks behind the
#controller.

#Device string for the disk
diskDev="/dev/sda"
#Number of disks in the array
arraySize=1
#Set to true to disable output on success
quietSuccess=FALSE

#Parse any incoming command-line arguments and overwrite the default-configured values
PARAMS=""
while (( "$#" )); do
  case "$1" in
    -d|--device)
      diskDev=$2
      shift 2
      ;;
    -n|--array-size)
      arraySize=$2
      shift 2
      ;;
    -q|--quiet-success)
      quietSuccess=TRUE
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done
# set positional arguments in their proper place
eval set -- "$PARAMS"

#Error message array
declare -a errorList=("   Command failed to parse"
 "   Device failed to open"
 "   SMART/ATA command failed"
 "   !!!DISK FAILING!!!"
 "   !!!DISK PREFAIL!!!"
 "   Disk reported OK but some attribute(s) below threshold!"
 "   Device error log contains errors!"
 "   Self-test log contains errors!"
)
#Decrement array size for 0-start sequence
((arraySize-=1))
#Iterate over each disk in the array
for raidDiskNo in $(seq 0 $arraySize); do
  #Use smartctl v7.1+ in silent mode to check disk health
  smartctl -d jmb39x,$raidDiskNo $diskDev -q silent
  #Get return status of previous command
  retStat=$?
  #Check for non-zero return status
  if [ $retStat -ne 0 ]; then
    #Print some relevant info for the record
    echo "Disk number $raidDiskNo reported a return status indicating errors present!"
    echo "The errors found are as follows:"
    #Iterate over each bit in return status
    for i in {0..7}; do
      #Generate bitmask to check if bit is set
      bitComp=$((2**$i))
      #Compare return value to bitmask for bit, store result in variable (Will only ever return non-zero if bit is set)
      bitValue=$(($retStat & $bitComp))
      #Check for non-zero response from bit comparison
      if [ $bitValue -ne 0 ]; then
        #Set the relevant error message from error array
        errorMsg=${errorList[i]}
        #Print the error for the record
        echo "$errorMsg"
      fi
    done
  #If return status from smartctl is 0, no errors were found for this disk
  else
    #Only print if enabled
    if [ "$quietSuccess" != "TRUE" ]; then
      #Print relevant disk number and success status for the record
      echo "No errors reported for disk number $raidDiskNo"
    fi
  fi
done
