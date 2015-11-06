#!/bin/bash
#(C) 2017 QuickPlay Media Inc.
#dennisp@quickplay.com
#
#ROGERS "PRE-ENCODE Process"
#Version 0.11 May 11 2017
#
#syntax: ./ROGERS_AEG_PRE.sh 1)SOURCE_FILE_LIST  2)NONE  3)DESTINATION_FOLDER  4)NONE  5)NONE  6)FFMPEG  7)FFPROBE 8)LOG 9)TECHMETA 10)DEBUG_MODE
#
#CHANGELOG: 
# AEG PRE 0.983 > ROGERS 0.1 LANGUAGE ENG, BITARTE RESTRICTIONS, REOLUTION ERROR HARD EXIT #VERSION 0.11 removed audio procvessing and xerror condition in all FFmpeg filters.

if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5" ]]
then
                echo "*********************************************"
                echo "Launching pre-processing of $1"
                echo "*********************************************"
else
                echo "Pleas check syntax: ./AEG_PEP.sh 1)SOURCE_FILE_LIST  2)DESTINATION_FOLDER  3)BinaryPath 4)TECHMETA 5)LOG 6)DEBUG_MODE"
                echo "$1 ERROR CODE 000-I missing module arguments"
                exit 1
fi


#Any OPTIONAL can be N, 0 or NONE to skip a feature.
SOURCE_FILE_LIST=$1             #Text file with source files. FFmpeg CONCAT demuxer format https://ffmpeg.org/ffmpeg-formats.html#concat
AUDIO_MAP=NONE                  #AT&T
DESTINATION_FOLDER=$2           #Destination folder for output files, LOGO and PREROLLS
SOURCE_TYPE=1                   #AT&T
OUTPUT_TYPE=1                   #AT&T
FFMPEG=$3/ffmpeg
FFPROBE=$3/ffprobe
TECH_META_URI=$4
LOG=$5
DEBUG=${6}                     #OPTIONAL, default=NO
SOURCE_FILE=$1

#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED.
if [ "$DEBUG" = 1 ] || [ "$DEBUG" = Y ] || [ "$DEBUG" = "DEBUG" ]
then
    set -vx
fi


#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(($RANDOM % 16))" | bc); done;)
mkdir PRE_ENC_TEMP_$rand
cd PRE_ENC_TEMP_$rand
export FFREPORT=file=ffrep.txt
FFDUMP=/dev/null
TECH_META=metadata.txt


#DATE LOG.
echo "JOBID:$rand `date` Initiating pre-processing of $SOURCE_FILE ">>$LOG
#STORE ALL VARS IN LOG.
echo "JOBID:$rand RECIEVED COMMAND: SCRIPT.sh $@">>$LOG


#********************
#* FILE TEST MODULE *
#********************
test_file()
{

SOURCE_PATH=$(dirname "${SOURCE_FILE}")
ACTUAL_FILE_ON_DISK=$(cat $SOURCE_FILE|grep -m 1 file| tr -s ' '|cut -d' ' -f2)
FILE_NAME=$(basename $ACTUAL_FILE_ON_DISK)
EXT=${FILE_NAME##*.}

case $EXT in
	[Mm][Pp][Gg])
		CONTAINER=TS
	;;
	[Tt][Ss])
		CONTAINER=TS
	;;
	*)
		echo "JOBID:$rand ERROR CODE 001F failed to identify source file type $EXT" >>$LOG
		rm -fr ./*
		echo "JOBID:$rand ERROR CODE 001F failed to identify source file type $EXT" >$TECH_META_URI
		exit 1
	;;
                
esac
echo "JOBID:$rand Source file type is $CONTAINER" >>$LOG
}


#*********************
#* AUDIO TEST MODULE *
#*********************
test_audio_track()
{
#GET SOURCE FILE SPECS for TESTS
#SET ALL AUDIO VARS
ALL_VARSA=$($FFPROBE -i $ACTUAL_FILE_ON_DISK -show_streams -select_streams a -of flat=s=_ 2>/dev/null)

if [ $? = 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE audio file data collected" >>$LOG
else
	echo "JOBID:$rand $SOURCE_FILE ERROR failed to read audio file" >>$LOG
	cat ffrep.txt >>$LOG
	echo "JOBID:$rand $SOURCE_FILE ERROR failed to read audio file" >$TECH_META_URI
	exit 1
fi

eval "$ALL_VARSA"
if [ $? = 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE collected audio data in proper format" >>$LOG
else
	echo "JOBID:$rand $SOURCE_FILE ffprobe collcted data can't be eval'd" >>$LOG
	exit 1
fi

#TEST ONLY FIRST AUDIO TRACK (ATT 05/2016)
atrack=0

#TEST AUDIO CODEC 
ffp_acodec=streams_stream_${atrack}_codec_name
if [ -n "${!ffp_acodec}" ]
then
	streams_stream_codec_name=$(echo "${!ffp_acodec}" | tr '[:upper:]' '[:lower:]')
	if [ $streams_stream_codec_name = mp2 ] || [ $streams_stream_codec_name = ac3 ] || [ $streams_stream_codec_name = eac3 ] 
    then
		echo "JOBID:$rand $SOURCE_FILE track $atrack has audio codec $streams_stream_codec_name " >>$LOG
    else
		echo "JOBID:$rand ERROR $SOURCE_FILE track $atrack has wrong audio codec $streams_stream_codec_name" >>$LOG
		echo "JOBID:$rand ERROR $SOURCE_FILE track $atrack has wrong audio codec $streams_stream_codec_name" >$TECH_META_URI
		exit 1
	fi
fi
                
#TEST SAMPLE RATE
ffp_afreq=streams_stream_${atrack}_sample_rate
if [ -n "${!ffp_afreq}" ]
then 
	streams_stream_sample_rate=$(echo "${!ffp_afreq}" | tr '[:upper:]' '[:lower:]')
	if [ $streams_stream_sample_rate = 44100 ] || [ $streams_stream_sample_rate = 48000 ]
	then
		echo "JOBID:$rand $SOURCE_FILE audio track $atrack has sample rate of $streams_stream_sample_rate" >>$LOG
	else
		echo "JOBID:$rand ERROR $SOURCE_FILE track $atrack has sample rate of $streams_stream_sample_rate Hz, while acceptable values are 44100 or 48000 Hz" >>$LOG
		echo "JOBID:$rand ERROR $SOURCE_FILE track $atrack has sample rate of $streams_stream_sample_rate Hz, while acceptable values are 44100 or 48000 Hz" >$TECH_META_URI
		exit 1
	fi
fi

#TEST AUDIO BITRATE
ffp_ab=streams_stream_${atrack}_bit_rate
if [ -n "${!ffp_ab}" ]
then 
	streams_stream_bit_rate=$(echo "${!ffp_ab}" | tr '[:upper:]' '[:lower:]')
	
	if [ $streams_stream_bit_rate -gt 120000 ] && [ $streams_stream_bit_rate -lt 13000000 ]
	then
		echo "JOBID:$rand $SOURCE_FILE audio track $atrack  has bitrate of $streams_stream_bit_rate " >>$LOG
	elif [ $streams_stream_bit_rate = N/A ]
	then
		echo "JOBID:$rand WARNING $SOURCE_FILE audio track $atrack  has no audio bitrate specified in the header. " >>$LOG
	else
		echo "JOBID:$rand ERROR $SOURCE_FILE audio track $atrack has bitrate of $streams_stream_bit_rate, while acceptable values are between 64k and 13000 kbps " >>$LOG
		echo "JOBID:$rand ERROR $SOURCE_FILE audio track $atrack has bitrate of $streams_stream_bit_rate, while acceptable values are between 64k and 13000 kbps " >$TECH_META_URI
		#exit 1
	fi
fi

#TEST CHANNELS (ONLY stereo and 5.1 for ATT 05/2016)
ffp_ac=streams_stream_${atrack}_channels
if [ -n "${!ffp_ac}" ]
then 
	streams_stream_channels=$(echo "${!ffp_ac}" | tr '[:upper:]' '[:lower:]')
	if [ $streams_stream_channels -eq 2 ] || [ $streams_stream_channels -eq 6 ]
	then
		echo "JOBID:$rand $SOURCE_FILE track ${atrack} has $streams_stream_channels chanels" >>$LOG
		echo "CHANNELS=$streams_stream_channels" >>$TECH_META
	else
		echo "JOBID:$rand ERROR $SOURCE_FILE track ${atrack} has wrong number of audio channles $streams_stream_channels" >>$LOG
		echo "JOBID:$rand ERROR $SOURCE_FILE track ${atrack} has wrong number of audio channles $streams_stream_channels" >$TECH_META_URI
		exit 1
	fi
fi

#PROBE AUDIO LANGUAGE METADTA AND STORE TO TECH_META ATT 05/2016
ffp_tl=streams_stream_${atrack}_tags_language
if [ -n "${!ffp_tl}" ]
then 
	streams_stream_langauge=$(echo "${!ffp_tl}" | tr '[:upper:]' '[:lower:]')
	echo "LANGUAGE=ENG" >>$TECH_META
fi

streams_stream_1_index=
}


#*********************
#* VIDEO TEST MODULE *
#*********************
test_video_track()
{
ALL_VARSV=$($FFPROBE -i $ACTUAL_FILE_ON_DISK -show_streams -select_streams v -of flat=s=_ 2>/dev/null)

if [ $? = 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE video header data collected" >>$LOG
else
	echo "JOBID:$rand $SOURCE_FILE ERROR failed to read video header data " >>$LOG
	cat ffrep.txt >>$LOG
	echo "JOBID:$rand ERROR $SOURCE_FILE failed to read video header data" >$TECH_META_URI
	exit 1
fi


eval "$ALL_VARSV"
if [ $? = 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE collected video data is in proper format" >>$LOG
else
	echo "JOBID:$rand ERROR $SOURCE_FILE ffprobe collcted data can't be eval'd" >>$LOG
	exit 1
fi


#TEST NUMBER OF VIDEO TRACKS
if [ -z $streams_stream_1_index ]
then 
	echo "JOBID:$rand $SOURCE_FILE has a single video track" >>$LOG
else
	echo "JOBID:$rand ERROR $SOURCE_FILE has TWO or more video tracks." >>$LOG
	echo "JOBID:$rand ERROR $SOURCE_FILE has TWO or more video tracks." >$TECH_META_URI
	exit 1
fi


#TEST FRAME RATE
if [ $(echo "scale=5;$streams_stream_0_r_frame_rate > 24000/1002"|bc) -eq 1 ] && [ $(echo "scale=5;$streams_stream_0_r_frame_rate < 60001/1000"|bc) -eq 1 ]
then
	echo "JOBID:$rand $SOURCE_FILE has framerate of rate of $streams_stream_0_r_frame_rate " >>$LOG
else
	if [ $(echo "scale=5;$streams_stream_0_r_frame_rate > 60"|bc) -eq 1 ]
	then
		echo "JOBID:$rand WARNING $SOURCE_FILE has frame rate of $streams_stream_0_r_frame_rate, while acceptable values are 24/25/30/48/60" >>$LOG
	elif [ $(echo "scale=5;$streams_stream_0_r_frame_rate < 24000/1002"|bc) -eq 1 ]
	then
		echo "JOBID:$rand ERROR $SOURCE_FILE has frame rate of $streams_stream_0_r_frame_rate, while acceptable values are 24/25/30/48/60" >>$LOG
		echo "JOBID:$rand ERROR $SOURCE_FILE has frame rate of $streams_stream_0_r_frame_rate, while acceptable values are 24/25/30/48/60" >$TECH_META_URI
		exit 1
	fi
fi


#TEST CODEC
streams_stream_0_codec_name=`echo "$streams_stream_0_codec_name" | tr '[:upper:]' '[:lower:]'`
if [ ${streams_stream_0_codec_name:0:4} = mpeg ] || [ $streams_stream_0_codec_name = h264 ]
then
	echo "JOBID:$rand $SOURCE_FILE has video codec $streams_stream_0_codec_name " >>$LOG
else
	echo "JOBID:$rand ERROR $SOURCE_FILE has wrong video codec $streams_stream_0_codec_name" >>$LOG
	echo "JOBID:$rand ERROR $SOURCE_FILE has wrong video codec $streams_stream_0_codec_name" >$TECH_META_URI
	exit 1
fi

#TEST DURATION OF VIDEO TRACK
if [ $streams_stream_0_duration = N/A ] || [ $streams_stream_0_duration = 0 ]
then 
	streams_stream_0_duration=$($FFPROBE -i $ACTUAL_FILE_ON_DISK -show_format 2>/dev/null </dev/null | grep duration | cut -d= -f2 | cut -d. -f1)
fi

#TEST VIDEO or FILE BITRATE
if [ $streams_stream_0_bit_rate = N/A ] || [ $streams_stream_0_bit_rate = 0 ]
then 
	size_on_disk=$(stat --printf="%s" $ACTUAL_FILE_ON_DISK)
	streams_stream_0_bit_rate=$(echo "$size_on_disk * 8 / $streams_stream_0_duration" |bc ) #add audio 
fi

if [ $streams_stream_0_bit_rate -gt 5000000 ] && [ $streams_stream_0_bit_rate -lt 60000000 ]
then
	echo "JOBID:$rand $SOURCE_FILE has bitrate of $streams_stream_0_bit_rate " >>$LOG
else
	echo "JOBID:$rand WARNING $SOURCE_FILE has bitrate of $streams_stream_0_bit_rate, while acceptable values are between 5 and 60 Mbit per second" >>$LOG
fi

#TEST RESOLUTION
if [ $streams_stream_0_width -gt 639 ] && [ $streams_stream_0_width -lt 1921 ]
then
	echo "JOBID:$rand $SOURCE_FILE has width of $streams_stream_0_width " >>$LOG
else
	echo "JOBID:$rand WARMING $SOURCE_FILE has width  of $streams_stream_0_width, must be between 640 and 1920" >>$LOG
	echo "JOBID:$rand ERROR $SOURCE_FILE has width  of $streams_stream_0_width, must be between 640 and 1920" >$TECH_META_URI
	exit 1
fi

if [ $streams_stream_0_height -gt 479 ] && [ $streams_stream_0_height -lt 1081 ]
then
	echo "JOBID:$rand $SOURCE_FILE has width of $streams_stream_0_height " >>$LOG
else
	echo "JOBID:$rand WARNING $SOURCE_FILE has height of $streams_stream_0_height, must be between 480 and 1080" >>$LOG
	echo "JOBID:$rand ERROR $SOURCE_FILE has height of $streams_stream_0_height, must be between 480 and 1080" >$TECH_META_URI
	exit 1
fi

v_codec=${streams_stream_0_codec_name}
v_width=${streams_stream_0_width}
v_height=${streams_stream_0_height}
DAR=${streams_stream_0_display_aspect_ratio}
SAR=${streams_stream_0_sample_aspect_ratio}
FPS=${streams_stream_0_r_frame_rate}

#STORE SOURCE FILE SPECS IN LOG.
echo "JOBID:$rand $SOURCE_FILE VIDEO SPECS ARE: Video Codec: $v_codec ; Height: $v_height ; Width: $v_width ; DAR: $DAR ; SAR: $SAR ; FPS: $FPS ;" >>$LOG
}


#*************************
#ASPECT RATIO and PADDING*
#*************************
set_aspect_ratio_and_crop()
{
#TEST SOURCE RESOLUTION HD / SD / too low.
let pix_count=$(( v_width * v_height ))
if [[ "$v_height" -lt 720 ]]
then
    PIX=SD
elif [[ "$v_height" = 720 ]] #NEW ATT PIX FORMAT FOR 60 fps 
then
	PIX=720
else 
    PIX=HD
fi

echo "JOBID:$rand $SOURCE_FILE is $PIX" >>$LOG
echo "PIX=$PIX" >>$TECH_META
#SAMPLE ASPECT RATIO
SAR1=${SAR%:*}
SAR2=${SAR#*:}

#TEST IF SAR HAS INVALID VALUES
if [[ "$SAR1" = 0 ]] || [[ "$SAR1" = 1 ]] || [[ "$SAR2" = 0 ]] || [[ "$SAR2" = 1 ]]
then 
    SAR=1
fi

#TEST IF DAR VALUES ARE VALID, IF NOT USE RESOLUTION AND PAR TO CALCULATE DAR. (REDUCED LOGIC FOR ATT 05/2016)
if [[ "$DAR" = "16:9" ]] || [[ "$DAR" = "4:3" ]] || [[ "$DAR" = "427:180" ]]
then 
    DAR=$DAR
elif [[ "$SAR" = "16:9" ]] || [[ "$SAR" = "4:3" ]] || [[ "$SAR" = "427:180" ]]
then
    DAR=$SAR
elif [[ "${v_width}x${v_height}" = "1280x720" ]] || [[ "${v_width}x${v_height}" = "1920x1080" ]]
then
    DAR=16:9
elif [[ "$DAR" = "5:4" ]] || [[ "$DAR" = "3:2" ]] #test for known wrong DAR
then
                DAR=4:3
fi


#LETTERBOX DETECT (two steps to save time 10 sec and then full duration video read)
if [[ "$DAR" = "4:3" ]] && [[ "$PIX" = SD ]]
then
	crop=$($FFMPEG -i $ACTUAL_FILE_ON_DISK -t 10 -an -vf cropdetect=22:2:0 -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1;exit ${PIPESTATUS[0]})
	exitstatus=$?
	
	if [ $exitstatus != 0 ]
	then
		echo "JOBID:$rand $SOURCE_FILE WARNING Crop detection process has failed, file might be malformed." >>$FFDUMP
		unset crop
	elif echo $crop | grep -q -e "${v_width}:${v_height}"
	then
		echo "JOBID:$rand $SOURCE_FILE DAR is $DAR", no cropping needed. >>$LOG
		unset crop
	else
	#long test entire file (at AT&T labs request)
	crop=$($FFMPEG -i $ACTUAL_FILE_ON_DISK -an -vf cropdetect=22:2:0 -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1;exit ${PIPESTATUS[0]})
	exitstatus=$?
	
	if [ $exitstatus != 0 ]
	then
		echo "JOBID:$rand $SOURCE_FILE WARNING Crop detection process has failed, file might be malformed." >>$FFDUMP
	elif echo $crop | grep -q -e "${v_width}:${v_height}"
	then
		echo "JOBID:$rand $SOURCE_FILE DAR is $DAR", no cropping needed. >>$LOG
		unset crop
	else
		echo "JOBID:$rand $SOURCE_FILE DAR is $DAR", cropping is applied to reduce file size to ${crop}. >>$LOG
		DAR=16:9
		crop=${crop},
	fi
    fi
fi


#STORE ASPECT IN LOGS
echo "DAR=$DAR" >>$TECH_META
echo "JOBID:$rand $SOURCE_FILE DAR is $DAR" >>$LOG

#SET ASPECT AND RESOLUTION FOR MEZZ GENERATION.
case $DAR in

	4:3)
	setdar='4:3'
		if [[ "$PIX" = SD ]]  
		then 
			mezz_rez=720:540
		else
			mezz_rez=960:720
		fi
	;;
	
	16:9)
	setdar='16:9'
		if [[ "$PIX" = SD ]]
		then
			mezz_rez=854:480
		else	
			mezz_rez=1280:720
		fi             
	;;

esac

echo "HEIGHT=${mezz_rez##*:}" >>$TECH_META
echo "WIDTH=${mezz_rez%%:*}" >>$TECH_META
}


#******************
#SCAN TYPE MODULE
#******************
set_scan_type()
{
best_ratio=0
full_duration=$($FFPROBE -i $ACTUAL_FILE_ON_DISK -show_format 2>&1| tee -a $FFDUMP | grep duration |cut -d= -f2|cut -d. -f1)

if [[ $full_duration = "N/A" ]]
then 
	full_duration=120
fi

fifth=$(echo "$full_duration/5"|bc)

if [[ $full_duration -lt 300 ]]
then
	seek_distance=$(( fifth / 2 ))
else
	seek_distance=$fifth
fi

#try up to 5 tests if file is of unceratain type
while [[ $seek_distance -lt $full_duration ]]
do
	# test for broken frames and skip ahead if needed just in case
	try=0
	while [ $try -lt 3 ]
	do 
		$FFMPEG $REPORT -ss $seek_distance  -i $ACTUAL_FILE_ON_DISK -ss 1 -vf idet -t 1 -an -f null /dev/null 2>/dev/null >/dev/null </dev/null
		exitstatus=$?
	
		if [ $exitstatus != 0 ]
		then
			seek_distance=$(( seek_distance + 1 ))
			try=$(( try + 1 ))
		else 
			try=3
		fi
	done
	
	if [ $exitstatus != 0 ]
	then
		echo "JOBID:$rand $SOURCE_FILE ERROR Maximum of 3 retries for scan detection reached, file seems to be malformed." >>$FFDUMP
		echo "ERROR processing $SOURCE_FILE, please read logs" >$TECH_META_URI
		cat ffrep.txt >>$LOG
		exit 1
	fi
	
			
	#seek_distance tested,  now analyze 5sec string
	frames=(`$FFMPEG $REPORT -ss $seek_distance -i $ACTUAL_FILE_ON_DISK -ss 1 -vf idet -sn -an -dn -t 15 -f null /dev/null 2>&1 | tee -a $FFDUMP |grep -e "Single frame" |awk -F'[:]' '{print $3, $4, $5, $6 }' OFS=' '; exit ${PIPESTATUS[0]}`)

	exitstatus=$?
	#Frames renumber 0)TOPFF, 1)BOTTOMFF, 2)PROGRESSIVE, 3)UNKNOWN.
	frames=(${frames[0]} ${frames[2]} ${frames[4]} ${frames[6]})
	uframe_ratio=$(echo "scale=2;( ${frames[0]} + ${frames[1]} + ${frames[2]}  + 1 ) / ( ${frames[3]} + 1 )"|bc)
	frame_ratio=$(echo "scale=3;( ${frames[0]} + 1 + ${frames[1]} + ${frames[3]} / 2 ) / ( ${frames[2]} + 1 + ${frames[3]} / 2 )"|bc)

	#test the analyzed frame types to determine entire file's format, read another segment if undetermined
	if [ $exitstatus != 0 ] || [ -z "${frames[*]}" ] || [ $(echo "${frames[3]} > ( ${frames[0]} + ${frames[1]} + ${frames[2]} ) / 2"|bc) -eq 1 ]
	then 
		seek_distance=$(( seek_distance + fifth ))
					
	elif [[ ${frames[2]} -ne 0 ]] && [[ ${frames[3]} -gt ${frames[2]} ]] || [[ ${frames[3]} -gt 21 ]]
	then 
		seek_distance=$(( seek_distance + fifth ))

		if [ $(echo "$uframe_ratio > $best_ratio"|bc) -eq 1 ]
		then
			best_ratio=$uframe_ratio
			best_set=(${frames[@]})
						
			if [ $(echo "$frame_ratio>3"|bc) -eq 1 ] && [ $(echo "$frame_ratio<6.5"|bc) -eq 1 ]
			then
				seek_distance=$full_duration
				best_ratio=0
				best_set=0
			fi
		fi

	elif [ $(echo "$frame_ratio>=5.5"|bc) -eq 1 ] && [ $(echo "$frame_ratio<8"|bc) -eq 1 ]
	then
		best_ratio=$uframe_ratio
		best_set=(${frames[@]})
		seek_distance=$(( seek_distance + fifth ))
				
	elif [ $(echo "$frame_ratio>=1.5"|bc) -eq 1 ] && [ $(echo "$frame_ratio<3"|bc) -eq 1 ]
	then
		best_ratio=$uframe_ratio
		best_set=(${frames[@]})
		seek_distance=$(( seek_distance + fifth ))
		
	else
		seek_distance=$full_duration
		best_ratio=0
		best_set=0
	fi
done

if [ $exitstatus != 0 ]; then
	echo "JOBID:$rand $SOURCE_FILE ERROR Maximum retries for scan detection reached, file seems to be malformed." >>$FFDUMP
	echo "JOBID:$rand ERROR processing $SOURCE_FILE"> $TECH_META_URI
	cat ffrep.txt >>$LOG
	exit 1
fi

if [[ $(echo "$best_ratio != 0"|bc) -eq 1 ]] && [[ $(echo "${frames[3]} != 0"|bc) -eq 1 ]]
then
	uframe_ratio=$(echo "scale=2;(${frames[0]} + ${frames[1]} + ${frames[2]})/${frames[3]}"|bc)
	
	if [ $(echo "$uframe_ratio < $best_ratio"|bc) -eq 1 ]
	then
		frames=(${best_set[@]})
	fi
fi

echo "JOBID:$rand $SOURCE_FILE Frame types: TFF/BFF/Progressive/Undetermined" >>$LOG
echo "JOBID:$rand $SOURCE_FILE ${frames[@]}" >>$LOG
avg=$(echo ${frames[3]}/2|bc)
iframes=$(( ${frames[0]} + ${frames[1]} + $avg ))
pframes=$(( ${frames[2]} + $avg ))

if   [ $pframes -eq 0 ]
then
	frame_ratio=0
	SCAN=INTERLACED
else        
	frame_ratio=$(echo "scale=3;$iframes/$pframes"|bc)

	if [ $(echo "$frame_ratio>2.5"|bc) -eq 1 ] && [ $(echo "$frame_ratio<6.5"|bc) -eq 1 ]
	then

		#BOLLYWOOD, SOUTH AMERICAN and EUROPEAN
		if [[ $( echo "$FPS" == "25" | bc ) -eq 1 ]] 
		then
			SCAN=INTERLACED
		else
			SCAN=TELECINED
		fi

	elif [ $pframes -gt $iframes ]
	then 
		SCAN=PROGRESSIVE
	else
		SCAN=INTERLACED
	fi
fi

echo "JOBID:$rand $SOURCE_FILE has $SCAN scan type" >>$LOG
}


#**************************
#* AUDIO VOLUME DETECTION *
#**************************
volume_detection()
{
VOLUME_TARGET=16    #average dB requested
AVG_VOL=$($FFMPEG -ss 25 -i $ACTUAL_FILE_ON_DISK  -vn -sn -dn -map a:0 -af volumedetect -t 120 -threads 0 -f null /dev/null 2>&1 | grep mean_volume|cut -d: -f2|cut -d- -f2|cut -d" " -f1)
BOOST=$(echo "${AVG_VOL} - ${VOLUME_TARGET}"/1|bc )

if [[ $(echo "$BOOST > 2"|bc) -eq 1 ]]
then
                echo "JOBID:$rand $SOURCE_FILE average volume is ${AVG_VOL}, boosting audio  by ${BOOST}." >>$LOG
else
                echo "JOBID:$rand $SOURCE_FILE average volume is ${AVG_VOL}. No boosting of audio is needed." >>$LOG
                BOOST=0
fi
}

#*********************
#* CHECK 60 FPS DUPS *
#*********************

sixty_fps_check()
{
seek=$fifth
$FFMPEG -ss $seek -i $ACTUAL_FILE_ON_DISK -an -vf mpdecimate -t 30 -f null /dev/null -report 2>/dev/null 
exitstatus=$?

if [ $exitstatus != 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE WARNING duplicate frame detection process has failed, file might be malformed." >>$FFDUMP
fi 

inframes=$(grep -P -o '\S+(?= frames decoded;)' ffrep.txt)
outframes=$(grep -P -o '\S+(?= packets muxed)' ffrep.txt); 
duplicate_rate=$(echo "scale=3;$inframes/$outframes"|bc)

rm ffrep.txt
lowest_duplicate_rate=$duplicate_rate


seek=$(( fifth + fifth ))
$FFMPEG -ss $seek -i $ACTUAL_FILE_ON_DISK -an -vf mpdecimate -t 30 -f null /dev/null -report 2>/dev/null 
exitstatus=$?

if [ $exitstatus != 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE WARNING duplicate frame detection process has failed, file might be malformed." >>$FFDUMP
fi 

inframes=$(grep -P -o '\S+(?= frames decoded;)' ffrep.txt)
outframes=$(grep -P -o '\S+(?= packets muxed)' ffrep.txt); 
duplicate_rate=$(echo "scale=3;$inframes/$outframes"|bc)

rm ffrep.txt

if [ $(echo "${lowest_duplicate_rate} > ${duplicate_rate}"|bc) -eq 1 ]
then 
	lowest_duplicate_rate="${duplicate_rate}"
fi



seek=$(( fifth + fifth + fifth ))
$FFMPEG -ss $seek -i $ACTUAL_FILE_ON_DISK -an -vf mpdecimate -t 30 -f null /dev/null -report 2>/dev/null 
exitstatus=$?

if [ $exitstatus != 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE WARNING duplicate frame detection process has failed, file might be malformed." >>$FFDUMP
fi 

inframes=$(grep -P -o '\S+(?= frames decoded;)' ffrep.txt)
outframes=$(grep -P -o '\S+(?= packets muxed)' ffrep.txt); 
duplicate_rate=$(echo "scale=3;$inframes/$outframes"|bc)

rm ffrep.txt

if [ $(echo "${lowest_duplicate_rate} > ${duplicate_rate}"|bc) -eq 1 ]
then 
	lowest_duplicate_rate="${duplicate_rate}"
fi

seek=$(( fifth + fifth + fifth + fifth ))
$FFMPEG -ss $seek -i $ACTUAL_FILE_ON_DISK -an -vf mpdecimate -t 30 -f null /dev/null -report 2>/dev/null 
exitstatus=$?

if [ $exitstatus != 0 ]
then
	echo "JOBID:$rand $SOURCE_FILE WARNING duplicate frame detection process has failed, file might be malformed." >>$FFDUMP
fi 

inframes=$(grep -P -o '\S+(?= frames decoded;)' ffrep.txt)
outframes=$(grep -P -o '\S+(?= packets muxed)' ffrep.txt); 
duplicate_rate=$(echo "scale=3;$inframes/$outframes"|bc)

rm ffrep.txt

if [ $(echo "${lowest_duplicate_rate} > ${duplicate_rate}"|bc) -eq 1 ]
then 
	lowest_duplicate_rate="${duplicate_rate}"
fi

if [[ $(echo "scale=3;$duplicate_rate >= 1.9" | bc) -eq 1 ]] && [[ $(echo "scale=3;$duplicate_rate <= 2.1" | bc) -eq 1 ]]
then 
	DUPS=30

elif [[ $(echo "scale=3;$duplicate_rate > 2.1" | bc) -eq 1 ]]
then
	DUPS=24

else 
	DUPS=60
fi
}


#********************
#CREATE MEZZ PROFILE
#********************
create_mezz_profile()
{
echo "JOBID:$rand $SOURCE_FILE is being encoded...." >>$FFDUMP

case $SCAN in

PROGRESSIVE)
	#check 60 fps files for inflated frame rate
	if [[ "${PIX}" = 720 ]] && [[ $(echo "scale=3;${FPS}>59"|bc) -eq 1 ]] 
	then
		sixty_fps_check
		case $DUPS in 
		30)
		QPMEZZ_ENC_PROFILE="-filter_complex ${crop}fps=30000/1001,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
		FPS=30000/1001
		;;
		24)
		QPMEZZ_ENC_PROFILE="-filter_complex ${crop}fps=30000/1001,decimate,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
		=24000/1001
		;;
		60)
		QPMEZZ_ENC_PROFILE="-filter_complex ${crop}fps=30000/1001,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
		;;
		esac

	else
		QPMEZZ_ENC_PROFILE="-filter_complex ${crop}scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
	fi
;;	
	
	
TELECINED)
	if [ ${frames[0]} -gt ${frames[1]} ]; then
		fieldmatch="fieldmatch=order=tff,yadif=parity=0"
	else
		fieldmatch="fieldmatch=order=bff,yadif=parity=1"
	fi
	
	QPMEZZ_ENC_PROFILE="-filter_complex ${crop}${fieldmatch},decimate,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
;;
	
	
INTERLACED)
	if [[ "${PIX}" = 720 ]] && [[ $(echo "scale=3;${FPS}>59"|bc) -eq 1 ]] 
	then	
		sixty_fps_check
		
		case $DUPS in 
		30)
			QPMEZZ_ENC_PROFILE="-filter_complex ${crop}fps=30000/1001,yadif,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
			FPS=30000/1001
		;;
		24)
			QPMEZZ_ENC_PROFILE="-filter_complex ${crop}fps=30000/1001,decimate,yadif,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
			FPS=24000/1001
		;;
		60)
			if [ ${frames[0]} -gt ${frames[1]} ]
			then
				yadif="yadif=mode=0:parity=0"
			else
				yadif="yadif=mode=0:parity=1"
			fi
			QPMEZZ_ENC_PROFILE="-filter_complex ${crop}${yadif},fps=30000/1001,scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
		;;
		esac
		
	else

		if [ ${frames[0]} -gt ${frames[1]} ]
		then
			yadif="yadif=mode=0:parity=0"
		else
			yadif="yadif=mode=0:parity=1"
		fi
		
		QPMEZZ_ENC_PROFILE="-filter_complex ${crop}${yadif},scale=${mezz_rez},setsar=1/1,setdar=$setdar,split=2[v1][v2]"
	fi
;;
	
esac
}



test_file
test_audio_track
test_video_track
set_aspect_ratio_and_crop
set_scan_type
volume_detection
create_mezz_profile


echo "FPS=$FPS" >>$TECH_META
echo "QPMEZZ_ENC_PROFILE=${QPMEZZ_ENC_PROFILE}" >>$TECH_META
echo "BOOST=${BOOST}" >>$TECH_META
echo "SCAN_TYPE=$SCAN" >>$TECH_META

echo "JOBID:$rand $SOURCE_FILE pre-processing is complete." >>$LOG

mv $TECH_META $TECH_META_URI
cd ..

exit $?