#! /bin/bash
# WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                   Version 2, December 2004
# 
#Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
# 
#Everyone is permitted to copy and distribute verbatim or modified
#copies of this license document, and changing it is allowed as long
#as the name is changed.
# 
#           DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#  TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
# 
# 0. You just DO WHAT THE FUCK YOU WANT TO.

# BURP check backup nagios plugin
# Read the last log file from a BURP backup and check age and warning of backup.
#
# TODO
# * Statistics gathering and state of backup depending of BURP version (use backup_stats if it exists, and fall back to log.gz)
# * Choose number of error for CRITICAL level


## Variables
#set -xv
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
PERFDATA=""
PERFDATAOPT=0

function usage()
{
	echo check_burp_backup.sh 1.1
	echo "This plugin read the backup_stats file (or log.gz for burp < 1.4.x) and check the age and warning of the backup."
	echo "Usage : -H <hostname> -d <directory> [-p] -w <minutes> -c <minutes>"
	echo "Options :"
	echo "-H Name of backuped host (see clientconfdir)"
	echo "-w WARNING number of minutes since last save "
	echo "-c CRITICAL number of minutes since last save"
	echo "-p Enable perfdata"
}

function convertToSecond()
{
	local S=$1
	((h=S/3600))
	((m=S%3600/60))
	((s=S%60))
	printf "%dh%dm%ds\n" $h $m $s
}


## Start


# Arguments check
if [ "$#" = "0" ]
then 
	usage
	exit $STATE_UNKNOWN
fi

# Manage arguments
while getopts hH:d:pw:c: OPT; do
	case $OPT in
		h)	
			usage
 			exit $STATE_UNKNOWN
			;;	
		d)
			DIR=$OPTARG
			;;
		H)
			HOST=$OPTARG
			;;
		w)
			WARNING=$OPTARG
			;;
		c)
			CRITICAL=$OPTARG
			;;
		p)
			PERFDATAOPT=1
			;;
		*)
			usage
 			exit $STATE_UNKNOWN
			;;	
	esac
done


if [ $WARNING -gt $CRITICAL ]
then
	echo "UNKNOWN : Warning level is greater than Critical level"
	exit $STATE_UNKNOWN
else
	WARNING=$(($WARNING * 60))
	CRITICAL=$(($CRITICAL * 60))

fi



LOG=$DIR/$HOST/current/log.gz

# Open last BURP backup log file
if [ ! -e $LOG ]
then
	echo "CRITICAL : $LOG doesn't exist!"
	exit $STATE_CRITICAL
fi


# Statistics gathering
WARNINGS=$(zgrep "Warnings" $LOG | awk '{print $NF}')
NEW=$(zgrep "Grand total" $LOG | awk '{print $3}')
CHANGED=$(zgrep "Grand total" $LOG | awk '{print $4}')
UNCHANGED=$(zgrep "Grand total" $LOG | awk '{print $5}')
DELETED=$(zgrep "Grand total" $LOG | awk '{print $6}')
TOTAL=$(zgrep "Grand total" $LOG | awk '{print $7}')

# date gathering
DATE=$(zgrep "End time: " $LOG | awk '{print $3}')
HEURE=$(zgrep "End time: " $LOG | awk '{print $4}')

ENDSTAMP=$(date -d "$DATE $HEURE" +%s)
NOW=$(date +%s)

LAST=$(($NOW-$ENDSTAMP))
LASTDIFF=$(convertToSecond $LAST)

if [ $PERFDATAOPT -eq 1 ]
then
	PERFDATA=$(echo "| warnings=$WARNINGS; new=$NEW; changed=$CHANGED; unchanged=$UNCHANGED; deleted=$DELETED; total=$TOTAL")
fi


if [ $LAST -gt $CRITICAL ]
then
	echo "CRITICAL : Last backup $LASTDIFF ago with $WARNINGS warnings $PERFDATA"
	exit $STATE_CRITICAL
else
	if [ $LAST -gt $WARNING ] || [ $WARNINGS -gt 200 ]
	then
		echo "WARNING : Last backup $LASTDIFF ago with $WARNINGS warnings $PERFDATA"
	        exit $STATE_WARNING
	else
		echo "OK : Backup without error $LASTDIFF ago $PERFDATA"
		exit $STATE_OK
	fi
fi

