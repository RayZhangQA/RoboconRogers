#!/bin/bash
#(C) 2017 QuickPlay Media Inc.
#dennisp@quickplay.com
#version 0.4 ROGERS_AEG_CC_AQC "CLOSED CAPTIONS AUTOMATIC QUALITY CHECK"
#July 14 2017
#
#syntax: ./ROGERS_CC_AQC.sh SOURCE_FILE CCEXTRACT CPC LOG TECH_METADATA DEBUG
#CHANGELOG: 
# AEG 0.7 > ROGERS 0.1. #VERSION 0.2 Added a temp folder same as DFW. removed unneeded lines. #0.3 switched to ccextract #0.4 /tmp -> /temp


SOURCE_FILE=$1   #MEDIA FILE WITH EMBEDDED CC FILE IN CONCAT FORMAT
CCEXTRACT=$2/ccextractor     #CCextractor binary, FFMPEG or Manzanita
CPC=$3           #CPC at SSH location e.g. attcc_dit@192.168.50.21
OUTPUT_FILE=$4   #OUTPUT FILE NAME for extracted CC file (would be .VTT)
TECH_META_URI=$5 #text file with names of generated CC files, indicating completion of the CC process
LOG=$6
DEBUG=$7


#TEST VARS
if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5" && -n "$6" ]] 
then
    echo "*********************************************"
    echo "******* Launching CC PROCESSING of $1 *******"
    echo "*********************************************"
else
    echo "Pleas check syntax: ./ROGERS_AEG_CC_AQC.sh 1)SOURCE_FILE 2)CCEXTRACT 3)OUTPUT 4)CPC 5)LOG 6)TECH_METADATA 7)DEBUG"
    exit 1
fi



#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(($RANDOM % 16))" | bc); done;)
mkdir CC_AQC_$rand
cd CC_AQC_$rand


#DATE LOG
echo "JOBID:$rand $(date) Initiating CC file analysis of $SOURCE_FILE ">>$LOG

#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED.
if [[ "$DEBUG" -eq 1 ]] 
then 
    set -xv
    FFDUMP=$LOG
fi

cctrack=1 #only 1 CC track is processed if present

SOURCE_FILE_NAME=`cat $SOURCE_FILE|grep file|cut -d' ' -f2`

$CCEXTRACT -$cctrack -out=webvtt -o out.vtt $SOURCE_FILE_NAME

#TEST EXECUTION EXIT CODE
if [ $? -ne 0 ]; then
    echo "JOBID:$rand $CC ERROR failed to extract CC file, maybe wrong binary version" >>$LOG
    echo "JOBID:$rand $CC ERROR failed to extrcat CC file, maybe wrong binary version" >$TECH_META_URI
    exit 1
else
    echo "JOBID:$rand $SOURCE_FILE CC file extraction test passed" >>$LOG
fi

#copy to access MAC nfs
cp out.vtt ${OUTPUT_FILE}_temp.vtt

ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=webvtt -input=${OUTPUT_FILE}_temp.vtt -export=timedtext_dfxp  -output=/temp/$rand.xml

#TEST EXECUTION EXIT CODE
if [ $? -ne 0 ]; then
    echo "JOBID:$rand $CC ERROR failed to convert CC file" >>$LOG
    echo "JOBID:$rand $CC ERROR failed to convert CC file" >$TECH_META_URI
    rm -fr /temp/$rand.xml
    exit 1
else
    echo "JOBID:$rand $SOURCE_FILE CC file conversion test passed" >>$LOG
fi

#SIGNAL SCRIPT COMPLETION TO INGESTION SYSTEM
echo "JOBID:$rand $${OUTPUT_FILE} CC file extraction and conversion tests passed"  >$TECH_META_URI
mv ${OUTPUT_FILE}_temp.vtt ${OUTPUT_FILE}_$cctrack.vtt
rm -fr /temp/$rand.xml

echo "${OUTPUT_FILE}_$cctrack.vtt"  >$TECH_META_URI
cd ..

exit 0