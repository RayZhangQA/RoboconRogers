#!/bin/bash
#(C) 2017 QuickPlay Media Inc.
#dennisp@quickplay.com
#
#ROGERS AEG "Closed Captions Conversion Process"
#Version 0.1 MAY 4 2017
#
#syntax: ./ROGERS_AEG_CCCP.sh SOURCE_FILE  FFPROBE LOG TECH_METADATA DEBUG
#
#CHANGELOG: 
# AEG 0.25 > ROGERS 0.1


SOURCE_FILE=$1
DESTINATION=$2 # shared NFS folder, accessible by CaptionMaker
FPS=$3 # NDF or DF or 0=none
OUT_FPS=$4 # NDF or DF or 0=none
OFFSET=$5 # HH:MM:SS:FF
OUTPUT_TYPE=$6 #0=VTT AND DFXP AND SRT OUTPUT, 1=DFXP OUTPUT, 2=VTT OUTPUT, 3=SRT
CPC=$7 #CPC is in SSH format e.g. attcc_dit@192.168.50.21
LOG=$8
TECH_META_URI=$9 #text file with names of generated CC files, indicating completion of the CC process
DEBUG=${10}



#TEST VARS
if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5"  && -n "$6"  && -n "$7"  && -n "$8"  && -n "$9"  && -n "${10}" ]] ; 
then
echo "*********************************************"
echo "******* Launching CC CONVERSION of $1 *******"
echo "*********************************************"
else
  echo "Pleas check syntax: ./CC_XBOX.sh 1)SOURCE_FILE  2)OUTPUT_FILE_NAME 3)INPUT TIMECODE 4)OUTPUT TIMECODE  5)OFFSET  6)OUTPUT_FILE_TYEP  7)CPC SSH   8)LOG  9)TECH_META 10)DEBUG_MODE"
  echo "$1 ERROR CODE 000-I missing module arguments"
  exit 1
fi



#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(($RANDOM % 16))" | bc); done;)

mkdir -p /$DESTINATION/$rand/

#VTT FIX
filename=$(basename "$SOURCE_FILE")
extension="${filename##*.}"
filename="${filename%.*}"
cp $SOURCE_FILE /$DESTINATION/$rand/$filename.vtt

#CC_NAME=${SOURCE_FILE##/*'/'}
#EXT=${CC_NAME##*.}
CC_NAME=$filename.vtt
EXT=vtt

#DATE LOG
echo "JOBID:$rand $(date) Initiating CC conversion process of $SOURCE_FILE ">>$LOG

#STORE ALL VARS IN LOG
echo "JOBID:$rand RECIEVED COMMAND: SCRIPT.sh $*">>$LOG


#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED.
if [[ "$DEBUG" -eq 1 ]] 
then 
	set -xv
	FFDUMP=$LOG
fi



#Check source CC type
check_file_ext()
{
case $EXT in
	[Ss][Mm][Ii])
		cctype=sami
	;;
	[Ss][Cc][Cc])
		cctype=scc
	;;
	[Xx][Mm][Ll])
		cctype=ttml
	;;
	[Vv][Tt][Tt])
		cctype=webvtt
	;;
	[Ss][Rr][Tt])
		cctype=subrip_srt
	;;
	[Ss][Tt][Ll])
		cctype=ebu_stl
	;;
	*)
	echo "JOBID:$rand $CC ERROR failed to identify CC source type" >>$LOG
	#rm -fr *
	exit 1
   ;;
esac
}

timing_options()
{
#BUILD COMMAND OPTIONS
if [[ "$OFFSET" == "0" ]]
then 
echo "JOBID:$rand $CC no offset value detected, pocessing file" >>$LOG
OFFSET="-command=rippletimecode,decrease,00:00:00:00"
else
echo "JOBID:$rand $CC offset value detected AT $offset, pocessing file" >>$LOG
OFFSET="-command=rippletimecode,decrease,$OFFSET"
fi


# check IN_FPS 
if [[ "$IN_FPS" == "NDF" ]]
then
	TCMODE=",changetcmode,29.97ndf"
elif [[ "$IN_FPS" == "DF" ]]
then
	TCMODE=",changetcmode,29.97df"
elif [[ "$IN_FPS" == "0" ]]
then
	TCMODE=
fi


# check OUT_FPS 
if [[ "$OUT_FPS" == "NDF" ]]
then
	TCMODE=",convert_tc_mode,29.97df,29.97ndf"
elif [[ "$OUT_FPS" == "DF" ]]
then
	TCMODE=",convert_tc_mode,29.97df,29.97ndf"
elif [[ "$OUT_FPS" == "0" ]]
then
	TCMODE=
fi
}

convert_file()
{
#ISSUE COMMAND
case "$OUTPUT_TYPE" in
0)
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=timedtext_dfxp ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.dfxp
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=webvtt ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.vtt
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=subrip_srt ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.srt
;;
1)
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=timedtext_dfxp ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.dfxp
;;
2)
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=webvtt ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.vtt
;;
3)
	ssh $CPC /Applications/MacCaption.app/Contents/MacOS/MacCaption -inhibit_gui -import=$cctype -input=/$DESTINATION/$rand/$CC_NAME -export=subrip_srt ${OFFSET}${TCMODE} -output=/$DESTINATION/$rand/$rand.srt
;;
esac

#TEST EXCUTION EXIT CODE
if [ $? -ne 0 ]; then
	echo "JOBID:$rand $CC ERROR failed to convert CC file" >>$LOG
	#rm -fr *
	exit 1
fi
}


check_file_ext
timing_options
convert_file


mv /$DESTINATION/$rand/$filename.vtt /$DESTINATION/$rand/$filename.vtt.backup
mv $DESTINATION/$rand/$rand.* $DESTINATION;
rm -rf $DESTINATION/$rand/

#SIGNAL SCRIPT COMPLETION TO INGESTION SYSTEM
ls -1 /$DESTINATION/$rand.* 2>/dev/null >$TECH_META_URI

exit 0
