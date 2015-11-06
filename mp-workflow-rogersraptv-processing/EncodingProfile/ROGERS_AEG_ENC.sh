# !/bin/bash
# (C) 2017 QuickPlay Media Inc.
# dennisp@quickplay.com
# ROGERS AEG-ARCH "E.N.C.O.D.E Process"
#
# Version 0.1  MAY 4 2017


if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5"  && -n "$6"  && -n "$7" ]] 
then
echo "*************************************************************************************"
echo "*** Launching transcoding of $1 ***"
echo "*************************************************************************************"
else
  echo "Please check syntax: ./AEG_EP.sh 1)SOURCE_FILE  2)OUTPUT_PREFIX  3)TECH_META 4)BINPATH  5)TECH_METADATA 6)LOG 7)DEBUG_MODE"
  echo "$1 ERROR CODE 000-I missing module arguments"
  exit 1
fi

SOURCE_FILE=$1
DESTINATION_FOLDER=$2
TECH_META_IN=$3 		#tech meta from pre-encoder
AUDIO_MAP=NONE 			#AT&T 05/2016
FFMPEG=$4/ffmpeg
FFPROBE=$4/ffprobe
NIELSEN_BIN_PATH=$4/PcmToId3
TECH_META_URI=$5
LOG=$6
DEBUG=$7


REPORT="-report"
export FFREPORT=file=ffrep.txt
FFDUMP=/dev/null
TECH_META=metadata.txt

#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(($RANDOM % 16))" | bc); done;)
mkdir ENC_TEMP_$rand
cd ENC_TEMP_$rand

#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED.
if [ "$DEBUG" = 1 ] || [ "$DEBUG" = Y ] || [ "$DEBUG" = "DEBUG" ]
then
    set -vx
    FDUMP=$LOG
fi

#DATE LOG.
echo "JOBID:$rand `date` Initiating transcoding process of $SOURCE_FILE ">>$LOG

#STORE ALL VARS IN LOG.
echo "JOBID:$rand RECIEVED COMMAND: SCRIPT.sh $@">>$LOG

#READ vars from TECH META
DAR=$(cat $TECH_META_IN|grep DAR|cut -d= -f2)
FPS=$(cat $TECH_META_IN|grep FPS|cut -d= -f2)
PIX=$(cat $TECH_META_IN|grep PIX|cut -d= -f2)
QPMEZZ_ENC_PROFILE=$(cat $TECH_META_IN|grep QPMEZZ_ENC_PROFILE)
QPMEZZ_ENC_PROFILE="${QPMEZZ_ENC_PROFILE/QPMEZZ_ENC_PROFILE=/}"
BOOST=$(cat $TECH_META_IN|grep BOOST|cut -d= -f2)
SCAN=$(cat $TECH_META_IN|grep SCAN_TYPE|cut -d= -f2)
ACHAN=$(cat $TECH_META_IN|grep CHANNELS|cut -d= -f2)
LANGUAGE=$(cat $TECH_META_IN|grep LANGUAGE|cut -d= -f2)
if [ -z "${LANGUAGE}" ]; then LANGUAGE=ORIG; fi

audio_boost()
{
#AUDIO ENCODE CONSTRUCT
if [[ "${BOOST}" = 0 ]] || [[ -z "${BOOST}" ]]
then
	BOOST_FILTER= 
else
	BOOST_FILTER="-filter:a volume=volume=${BOOST}dB"
fi
}


set_encoding_profiles()
{
#SET ENCODING PROFILES VARS
A_ENCODING="-map 0:a:0 $BOOST_FILTER -vn -sn -dn -c:a libfdk_aac -cutoff 18000 -ac 1 -b:a 32k AUD_ENG_32.mp4 \
-map 0:a:0 $BOOST_FILTER -vn -sn -dn -c:a libfdk_aac -cutoff 18000 -ac 2 -b:a 64k AUD_ENG_64.mp4 \
-map 0:a:0 $BOOST_FILTER -vn -sn -dn -c:a libfdk_aac -cutoff 20000 -ac 2 -b:a 96k AUD_ENG_96.mp4 \
-map 0:a:0 $BOOST_FILTER -vn -sn -dn -c:a libfdk_aac -cutoff 20000 -ac 2 -b:a 128k AUD_ENG_128.mp4"


AEG_01_V4000_BITRATE="4000"; AEG_01_V2600_BITRATE="2600"; AEG_01_V1800_BITRATE="1800"; AEG_01_V1200_BITRATE="1200"; AEG_01_V700_BITRATE="710"; AEG_01_V400_BITRATE="400"; AEG_01_V128_BITRATE="140"

if [[ "$DAR" = 16:9 ]]
then
	
	case $PIX in
	"SD")
		AEG_01_V2600_SIZE="960:540"
		AEG_01_V1800_SIZE="848:480"
		AEG_01_V1200_SIZE="848:480"
		AEG_01_V700_SIZE="640:360"
		AEG_01_V400_SIZE="400:224"
		AEG_01_V128_SIZE="320:176"
	;;

	*)
		AEG_01_V4000_SIZE="1280:720"
		AEG_01_V2600_SIZE="1280:720"
		AEG_01_V1800_SIZE="848:480"
		AEG_01_V1200_SIZE="848:480"
		AEG_01_V700_SIZE="640:360"
		AEG_01_V400_SIZE="400:224"
		AEG_01_V128_SIZE="320:176"
	;;
	esac
	
elif [[ "$DAR" = 4:3 ]]
then

	case $PIX in 
	"SD")
		AEG_01_V2600_SIZE="720:540"
		AEG_01_V1800_SIZE="640:480"
		AEG_01_V1200_SIZE="640:480"
		AEG_01_V700_SIZE="480:360"  
		AEG_01_V400_SIZE="360:272"
		AEG_01_V128_SIZE="320:240"                     
	;;
	esac

fi

GOP=$(echo "scale=0;$FPS*4/1" | bc)
}




encode_file()
{
#ENCODE
case $PIX in
SD)

	#SD encode
	$FFMPEG -y -analyzeduration 50M -threads 0 -f concat -safe 0 -i $SOURCE_FILE ${QPMEZZ_ENC_PROFILE} \
	-map [v1] -map 0:a:0 -s ${AEG_01_V2600_SIZE} -b:v ${AEG_01_V2600_BITRATE}k -maxrate $(echo "${AEG_01_V2600_BITRATE}*1.5/1"|bc)k -bufsize  $(echo "${AEG_01_V2600_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -c:a copy -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 1 -passlogfile aeg_01 -f mp4 /dev/null \
	-map "[v2]" -map 0:a -vcodec mpeg4 -qscale:v 2 -maxrate 15M -c:a copy -pix_fmt yuv420p -threads 0 -xerror $rand.qpmezz.mov \
	${NIELSEN_EXTRACT} 2>&1

	exitcode=$?
	
	#TEST FFMPEG EXIT CODE
	if [ "$exitcode" = 0 ]
		then
		echo "JOBID:$rand $SOURCE_FILE Finished Pass 1 successfully." >>$LOG
		
	else
	
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 1. Please check the source file for errors. " >>$LOG
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 1. Please check the source file for errors. " >$TECH_META_URI
		cat ffrep.txt >>$LOG
		rm ./*
		exit 1
	fi
	
	while [[ $l -lt 10 ]]; do 
		ln -s aeg_01-0.log aeg_01-$l.log
		ln -s aeg_01-0.log.mbtree aeg_01-$l.log.mbtree
		l=$((l+1))
	done
	
	
	$FFMPEG $REPORT -y  -analyzeduration 50M  -threads 0 -i $rand.qpmezz.mov -y \
	-s ${AEG_01_V2600_SIZE} -b:v ${AEG_01_V2600_BITRATE}k -maxrate $(echo "${AEG_01_V2600_BITRATE}*1.5/1"|bc)k -bufsize $(echo "${AEG_01_V2600_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V2600_BITRATE}.mp4 \
	-s ${AEG_01_V1800_SIZE} -b:v ${AEG_01_V1800_BITRATE}k -maxrate $(echo "${AEG_01_V1800_BITRATE}*1.3/1"|bc)k  -bufsize $(echo "${AEG_01_V1800_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V1800_BITRATE}.mp4 \
	-s ${AEG_01_V1200_SIZE} -b:v ${AEG_01_V1200_BITRATE}k -maxrate $(echo "${AEG_01_V1200_BITRATE}*1.3/1"|bc)k -bufsize $(echo "${AEG_01_V1200_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V1200_BITRATE}.mp4 \
	-s ${AEG_01_V700_SIZE} -b:v ${AEG_01_V700_BITRATE}k -maxrate $(echo "${AEG_01_V700_BITRATE}*1.25/1"|bc)k -bufsize $(echo "${AEG_01_V700_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V700_BITRATE}.mp4 \
	-s ${AEG_01_V400_SIZE} -b:v ${AEG_01_V400_BITRATE}k -maxrate $(echo "${AEG_01_V400_BITRATE}*1.2/1"|bc)k -bufsize $(echo "${AEG_01_V400_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V400_BITRATE}.mp4 \
	-s ${AEG_01_V128_SIZE} -b:v ${AEG_01_V128_BITRATE}k -maxrate ${AEG_01_V128_BITRATE}k -bufsize $(echo "${AEG_01_V128_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V128_BITRATE}.mp4 \
	$A_ENCODING 2>&1
	
	
	exitcode=$?
	
	#TEST FFMPEG EXIT CODE
	if [ "$exitcode" = 0 ]
		then
		echo "JOBID:$rand $SOURCE_FILE Finished Pass 2 successfully." >>$LOG
	else
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 2. Please check the source file for errors. " >>$LOG
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 2. Please check the source file for errors. " >$TECH_META_URI
		cat ffrep.txt >>$LOG
		rm ./*
		exit 1
	fi
;;

*)
	$FFMPEG -y -analyzeduration 50M -threads 0 -f concat -safe 0 -i $SOURCE_FILE ${QPMEZZ_ENC_PROFILE} \
	-map "[v1]" -map 0:a:0 -b:v ${AEG_01_V4000_BITRATE}k -maxrate $(echo "${AEG_01_V4000_BITRATE}*1.5/1"|bc)k -bufsize $(echo "${AEG_01_V4000_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -c:a copy -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 1 -passlogfile aeg_01 -f mp4 /dev/null \
	-map "[v2]" -map 0:a:0 -vcodec mpeg4 -qscale:v 2 -maxrate 35M -c:a copy -threads 0 -sn -dn -xerror $rand.qpmezz.mov \
	2>&1
	
	exitcode=$?
	
	#TEST FFMPEG EXIT CODE
	if [ "$exitcode" = 0 ]
	then
		echo "JOBID:$rand $SOURCE_FILE Finished Pass 1 successfully." >>$LOG
	else
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 1. Please check the source file for errors. " >>$LOG
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 1. Please check the source file for errors. " >$TECH_META_URI
		cat ffrep.txt >>$LOG
		rm ./*
		exit 1
	fi
	
	while [[ $l -lt 22 ]]; do 
		ln -s aeg_01-0.log aeg_01-$l.log
		ln -s aeg_01-0.log.mbtree aeg_01-$l.log.mbtree
		l=$((l+1))
	done
	

	
	$FFMPEG $REPORT -y  -analyzeduration 50M  -threads 0 -i $rand.qpmezz.mov -y \
	-s ${AEG_01_V4000_SIZE} -b:v ${AEG_01_V4000_BITRATE}k -maxrate $(echo "${AEG_01_V4000_BITRATE}*1.3/1"|bc)k -bufsize $(echo "${AEG_01_V4000_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V4000_BITRATE}.mp4 \
	-s ${AEG_01_V2600_SIZE} -b:v ${AEG_01_V2600_BITRATE}k -maxrate $(echo "${AEG_01_V2600_BITRATE}*1.3/1"|bc)k -bufsize $(echo "${AEG_01_V2600_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V2600_BITRATE}.mp4 \
	-s ${AEG_01_V1800_SIZE} -b:v ${AEG_01_V1800_BITRATE}k -maxrate $(echo "${AEG_01_V1800_BITRATE}*1.3/1"|bc)k  -bufsize $(echo "${AEG_01_V1800_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V1800_BITRATE}.mp4 \
	-s ${AEG_01_V1200_SIZE} -b:v ${AEG_01_V1200_BITRATE}k -maxrate $(echo "${AEG_01_V1200_BITRATE}*1.3/1"|bc)k -bufsize $(echo "${AEG_01_V1200_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V1200_BITRATE}.mp4 \
	-s ${AEG_01_V700_SIZE} -b:v ${AEG_01_V700_BITRATE}k -maxrate $(echo "${AEG_01_V700_BITRATE}*1.25/1"|bc)k -bufsize $(echo "${AEG_01_V700_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V700_BITRATE}.mp4 \
	-s ${AEG_01_V400_SIZE} -b:v ${AEG_01_V400_BITRATE}k -maxrate $(echo "${AEG_01_V400_BITRATE}*1.2/1"|bc)k -bufsize $(echo "${AEG_01_V400_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V400_BITRATE}.mp4 \
	-s ${AEG_01_V128_SIZE} -b:v ${AEG_01_V128_BITRATE}k -maxrate ${AEG_01_V128_BITRATE}k -bufsize $(echo "${AEG_01_V128_BITRATE}/4"|bc)k -g $GOP -c:v libx264 -profile:v high -trellis 2 -x264-params rc_lookahead=96 -refs 7 -bf 6 -i_qfactor 2.99 -pass 2 -passlogfile aeg_01 -an AEG_01_${AEG_01_V128_BITRATE}.mp4 \
	$A_ENCODING 2>&1

	exitcode=$?
	
	#TEST FFMPEG EXIT CODE
	if [ "$exitcode" = 0 ]
	then
		echo "JOBID:$rand $SOURCE_FILE Finished Pass 2 successfully." >>$LOG
	else
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 2. Please check the source file for errors. " >>$LOG
		echo "JOBID:$rand $SOURCE_FILE ERROR failed to encode QPMEZZ file and Pass 2. Please check the source file for errors. " >$TECH_META_URI
		cat ffrep.txt >>$LOG
		rm ./*
		exit 1
	fi
;;
esac
}


audio_boost
set_encoding_profiles
encode_file


echo "JOBID:$rand $SOURCE_FILE All done ***" >>$LOG
#move QPMEZZ with PASSLOG FILES TO DESTINATION TO ARCHIVE
#move ENCODED FILES TO DESTINATION FOLDER FOR PACKAGING
mv $rand.qpmezz.mov *.mp4 aeg_01-0.log.mbtree aeg_01-0.log nielsen.tar.bz2  "$DESTINATION_FOLDER" 2>/dev/null
echo "JOBID:$rand $SOURCE_FILE encoding completed, encoded files, mezzanine and pass logs are stored in  $DESTINATION_FOLDER " >>$LOG
ls -a1 $DESTINATION_FOLDER/*.mp4 >> $TECH_META_URI
echo "PIX=${PIX}" >> $TECH_META_URI


cd ..

exit 0
