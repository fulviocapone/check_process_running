#!/bin/bash
#####################################################################################
# Sample Nagios plugin to monitor occurrences of the process running on the machine #
# Author: Fulvio Capone                                                             #
#####################################################################################

VERSION="Version 1.1"
AUTHOR="2015 Fulvio Capone (fulvio.capone@gmail.com)"

PROGNAME=`type $0 | awk '{print $3}'`  # search for executable on path
PROGNAME=`basename $PROGNAME`          # base name of program

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Helper functions #############################################################

function print_revision {
   # Print the revision number
   echo "$PROGNAME - $VERSION - AUTHOR"
}

function print_usage {
   # Print a short usage statement
   echo "Usage: $PROGNAME [-v] -w <limit> -c <limit> -p <process name>"
}

function print_help {
   # Print detailed help information
   print_revision
   echo "$AUTHOR\n\nCheck number of PIDS active on the machine\n"
   print_usage

   /bin/cat <<__EOT

Options:
-h
   Print detailed help screen
-V
   Print version information
-w INTEGER
   Exit with WARNING status if less than INTEGER of PIDS Active
-c INTEGER
   Exit with CRITICAL status if less than INTEGER of PIDS Active
-p STRING
   The nameof the process to monitor
-v
   Verbose output
__EOT
}
# Main #########################################################################
# Verbosity level
verbosity=0
# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=
# Process
process=""
# Number of PIDS active
numprocess=0

# Parse command line options
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -V | --version)
           print_revision
           exit $STATE_OK
           ;;
       -v | --verbose)
           : $(( verbosity++ ))
           shift
           ;;
       -w | --warning | -c | --critical)
           if [[ -z "$2" || "$2" = -* ]]; then
               # Threshold not provided
               echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
           elif [[ "$2" =~ [0-9] ]]; then
               # Threshold is a number
               thresh=$2
           else
               # Threshold is neither a number nor a percentage
               echo "$PROGNAME: Threshold must be integer"
               print_usage
               exit $STATE_UNKNOWN
           fi
           [[ "$1" = *-w* ]] && thresh_warn=$thresh || thresh_crit=$thresh
           shift 2
           ;;
	   -p | --process)
			if [[ -z "$2" || "$2" = -* ]]; then
			# Process name not provided
			echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
		   elif [[ "$2" =~ [^a-zA-Z0-9] ]]; then
               # Process is a string
               process=$2
			   PIDS=`ps -ef | grep -v grep | grep $process | awk '{print $2}'`
           else
               # Threshold is neither a number nor a percentage
               echo "$PROGNAME: Process must be a string. You are entered the value: $2"
               print_usage
               exit $STATE_UNKNOWN
           fi
		   shift 2
		   ;;
       -?)
           print_usage
           exit $STATE_OK
           ;;
       *)
           echo "$PROGNAME: Invalid option '$1'"
           print_usage
           exit $STATE_UNKNOWN
           ;;
   esac
done

if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
   # One or both thresholds were not specified
   echo "$PROGNAME: Threshold not set"
   print_usage
   exit $STATE_UNKNOWN
elif [[ "$thresh_warn" -lt "$thresh_crit" ]]; then
   # The critical threshold must be greater than the warning threshold
   echo "$PROGNAME: Critical ($thresh_crit) number of PIDS should be smaller than warning ($thresh_warn) number of PIDS"
   print_usage
   exit $STATE_UNKNOWN
fi

if [[ "$verbosity" -ge 1 ]]; then
   # Print debugging information
   /bin/cat <<__EOT
Debugging information:
  Warning threshold: $thresh_warn
  Critical threshold: $thresh_crit
  Verbosity level: $verbosity
  Process: $process
__EOT
fi

if [ -z "$PIDS" ]; then
  echo "$(date +"%F %T") CRITICAL - Process '$process' is not running."
  exit $STATE_CRITICAL
else
  echo "Process is running."
  for PID in $PIDS; do
	(( numprocess++ ))
    echo $PID
  done
  if [[ "$numprocess" -lt "$thresh_crit" ]]; then
	   # Number of PIDS of the process is less than the critical threshold
	   echo "$(date +"%F %T") CRITICAL - $numprocess PIDS of the process '$process' are active."
	   exit $STATE_CRITICAL
	elif [[ "$numprocess" -lt "$thresh_warn" ]]; then
	   # Number of PIDS of the process is less than the warning threshold
	   echo "$(date +"%F %T") WARNING - $numprocess PIDS of the process '$process' are active."
	   exit $STATE_WARNING
	else
	   # Number of PIDS of the process is greater than the warning threshold!
	   echo "$(date +"%F %T") OK - $numprocess PIDS of the process '$process' are active."
	   exit $STATE_OK
	fi
fi
