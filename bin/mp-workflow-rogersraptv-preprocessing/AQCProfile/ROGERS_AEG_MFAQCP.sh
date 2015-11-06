#!/bin/bash
#(C) 2017 QuickPlay Media Inc.
#dennisp@quickplay.com
#
#AEG "Media Analyzer AQC"
#version 1.2  March 10 2016
#
#syntax: ./AEG_MFAQCP.sh SOURCE_FILE  FFPROBE LOG TECH_METADATA DEBUG
#
#CHANGELOG: 
#0.01 added extended error codes
#0.2 changed logging routing to "tee"; removed all QPMEZZ logic that is not relevant.
#0.3 reduced API requirements to 5. Cleaned up the temp files on error.
#0.4 API polishing up, adjusted erro codes, added file format read.
#1.0 Release, syntax fixed up.
#1.1 Added JOBID to techmeta for logging reference.
#1.2 changed outptu to JSON format as per Henok's request.

if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5" ]]
then
   echo "*********************************************"
   echo "******** Launching transcoding of $1 ********"
   echo "*********************************************"
else
   echo "Please check syntax: ./QPMEZZ_SINGTEL.sh 1)SOURCE_FILE 2)FFPROBE  3)LOG  4)TECH_METADATA  5)DEBUG_MODE"
   echo "$1 ERROR CODE 000-I missing module arguments" > >(tee -a "$3" "$4")
   exit 1
fi

SOURCE_FILE=$1
FFPROBE=$2
LOG=$3
TECH_META_URI=$4
DEBUG=$5

#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED.
if [ "$DEBUG" = "1" ] || [ "$DEBUG" = Y ] || [ "$DEBUG" = "DEBUG" ] 
then 
    set -vx
fi

#high detail report file for FFmpeg and FFprobe, generated on each run, dump to log in case of error
export FFREPORT=file=ffrep.txt

#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(( RANDOM % 16))" | bc); done;)
TECH_META=$rand.metadata.txt
	
#DATE LOG
echo "JOBID:$rand $(date) Initiating file analysis of $SOURCE_FILE ">>$LOG

#STORE ALL VARS IN LOG
echo "JOBID:$rand RECIEVED COMMAND: SCRIPT.sh $*">>$LOG


#******************
#FILE TEST MODULE
#******************


#TEST FILE EXTENSION
FILE_NAME=${SOURCE_FILE##/*'/'}
EXT=${FILE_NAME##*.}
case $EXT in
	[Mm][Pp][Gg])
	FILE_CONTAINER=TS
	;;
	[Mm][Pp][Ee][Gg])
	FILE_CONTAINER=TS
	;;
	[Tt][Ss])
	FILE_CONTAINER=TS
	;;
	[Mm][2][Tt])
	FILE_CONTAINER=TS
	;;
	[Mm][Pp][4])
	FILE_CONTAINER=MP4
	;;
	[Mm][Oo][Vv])
	FILE_CONTAINER=MP4
	;;
	[Mm][Xx][Ff])
	FILE_CONTAINER=TS
	;;
	*)
	echo "JOBID:$rand ERROR CODE 000F failed to identify  source file type $EXT" > >(tee -a $LOG $TECH_META_URI)
	exit 1
	;;
esac


#GET SOURCE FILE SPECS

$FFPROBE -i $SOURCE_FILE -show_streams -show_format -of json 2>/dev/null >$TECH_META

if [ $? = 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE audio file data collected" >>$LOG
else
	echo "JOBID:$rand $SOURCE_FILE ERROR CODE 001A failed to read audio header data" > >(tee -a $LOG $TECH_META_URI)
	cat ffrep.txt >>$LOG 2>/dev/null
	rm $TECH_META 2>/dev/null
	exit 1
fi

echo "JOBID:$rand" >$TECH_META_URI
cat $TECH_META >> $TECH_META_URI
rm $TECH_META
exit $?
