#!/bin/bash
#(C) 2017 QuickPlay Media Inc.
#Version 0.1 May 19 2017.
#
#AEG 0.24 > ROGERS 0.1 changed language to eng.
# A0.2 set to two (hls and dash) .ism files, removed unnecessary supporting structures




if [[ -e "$1" && -n "$2"  && -n "$3"  && -n "$4"  && -n "$5"  && -n "$6"  && -n "$7" && -n "$8" ]]; then
  echo "*********************************************"
  echo "Launching packaging of $1"
  echo "*********************************************"
else
  echo "Pleas check syntax: ./QPMEZZ_SINGTEL.sh 1)SOURCE_FILE  2)OUTPUT_PREFIX  3)FFMPEG  4)FFPROBE  5)LOG  6)TECH_METADATA  7)DEBUG_MODE"
  echo "$1 ERROR CODE 000-I missing module arguments" > >(tee -a "${10}" "${11}")
  exit 1
fi
 
SOURCE_FILE_LIST=$1                                                 #Text file with source files. Encoded media assets including de-muxed versions for TVVOD if required. ALL ISMV and ISMA
SOURCE_CC_FILES=$2                                                 #OPTIONAL CC Files list (DFXP and/or VTT)
DESTINATION_FOLDER=$3                                         #Destination folder for packaged files. Subfolder will created for each output types
#SOURCE_TYPE=$3                                                                      #1=LONG_FORM_BBV/2=LONG_FORM_TVVOD/3=SPORT/4=SPORT_CLIP/5=TRAILER_BBV/6=TRAILER_TVVOD
#OUTPUT_TYPE=$4                                                                     #1=BBV/2=TVVOD/3=SPORTS/4=BBV_and_TVVOD/5=nDRM.2
KEYS=$4                                                                                                         #LIST OF ALL NECCESARY DRM KEYS; key1=xxxx <CR> key2=yyyy
FFPROBE=$5                                                                                  #FOR FRAME RATE CALCULATION
MP4SPLIT=$6                                                                                #nDRM PACKAGER
#MANZANITA=$9                                                                         #TVVOD PACKAGER
#AUTHENTEC_BATCH_ENCRYPT=${10}    #AUTHENTEC packager
LOG=$7                                                                                           #LOG FILE to APPEND TO
TECH_META_URI=$8                                                    #TECHMETA
DEBUG=$9                                                                                     #OPTIONAL, DEBUG MORE default=NO
LIC_KEY='--license-key=aXQtb3BzZ3JvdXBAcXVpY2twbGF5LmNvbXwyMDE1MTEwMSAwMDowMDowMCwzOTB8cGFja2FnZShpc3MpO3N0cmVhbSh2b2QsbGl2ZSk7ZHJtKGFlcyxzYW1wbGVfYWVzLHBsYXlyZWFkeSx3aWRldmluZSxwaWZmMmNlbmMpO2lvX29wdCgpO2NhcHR1cmUoKTtjaGVjaygpO3N1cHBvcnQoMSk7b2VtKCl8dmVyc2lvbigxNzQwKXw5ODJmYzZlN2E1OTY0NTI2OGY2YzM5NDQwM2I3ZTBjMXwwMzA5MGVkNzcxNDA5OTAyNTE4NmMyY2Q3NzFkYmY4MjJjMTNjOGY5MWJiYWQ1NTJjOTU0NGMzNTZiOTdhNGUwMTRmZDk0YTAyY2I2YzE2NzIwN2E5ODg0NGIyZjkyMmY2MDY3NTI2YmJlMGU2OTMzODkyYmJhMzU1NDA4MTc5MTJlNzY1OTY1NGExMWU2ZTY2NDExOGZhODE4MmMwODY1OWMxZTk3NjM0YzA5NmFjZmVmYWI5ODQ1NmY4YWEwY2MxYTc1YWVjMzA0YWZhYjQ0YmFlZDYyZDcxYzFjYjMwNTc3ZTIzZDc0MGY0YzgyZDUxZThlYWM1MWVlMTE4Njhj'

 


 
#SET DEBUG (PLEASE ROUTE ALL STDOUT OF THE SCRIPT TO A LOG FILE WHEN DEBUG IS USED
if [ "$DEBUG" -eq 1 ] || [ "$DEBUG" = Y ] || [ "$DEBUG" = "DEBUG" ]; then
    set -vx
fi
TECH_META=metadata.txt
#SET UID FOR A JOB.
rand=$(for i in $(seq 1 10); do echo -n $(echo "obase=16; $(($RANDOM % 16))" | bc); done;)
mkdir TEMP_$rand
cd TEMP_$rand
#DATE LOG.
echo "JOBID:$rand `date` Initiating PACKAGING PROCESS of $SOURCE_FILE_LIST ">>$LOG
#STORE ALL VARS IN LOG.
echo "JOBID:$rand RECIEVED COMMAND: SCRIPT.sh $@">>$LOG
 
#finish later, use standard 9 for now.
FRAG_LENGTH=9
manifest_name="output"

#NOT USE LICENSE KEY FOR MP4SPLIT
unset LIC_KEY
 
DRM=0
hlsManifestArgs=" --hls.client_manifest_version 5 --hls.minimum_fragment_length $FRAG_LENGTH ";
LAURL=""

#READING DRM KEYS
if [ $KEYS != NONE ] && [ $KEYS != "N/A" ] && [ $KEYS != 0 ] && [ $KEYS != N ]; then
    KID=$(cat $KEYS |grep KID|cut -d= -f2)
    CEK=$(cat $KEYS |grep CEK|cut -d= -f2)
    KEY_IV=$(cat $KEYS |grep KEY_IV|cut -d= -f2)
    SKD_URL=$(cat $KEYS |grep SKD_URL|cut -d= -f2)
    
    DRM=1

    #reformate KID to form 8-4-4-4-12
    newKid=$(sed -e "s/\(........\)\(....\)\(....\)\(....\)\(....\)/\1-\2-\3-\4-\5/"<<<$KID)
    echo $newKid;
    
    #convert bparam to hex
    hex=$(echo -n "action=602||cid=cid:#$newKid@test.domain" |xxd -p -u)

    #remove space in hex
    hexBPARAM="${hex//[[:space:]]/}"
    
    #Construct LA.URL for iss
    #--iss.license_server_url=MSSLicenseURLBase?b=hex(action=602||cid=cid:#kid@test.domain)
    
    LAURL=$LAURL"http://pr.quickplay.com/mytv/license.pr?b="$hexBPARAM;
    echo $LAURL
    
    hlsManifestArgs=$hlsManifestArgs" --key=$KID:$CEK --hls.content_key=$CEK --hls.key_iv=$KEY_IV --hls.license_server_url=skd://$SKD_URL --hls.playout=sample_aes_streamingkeydelivery ";
                              
fi

CC=0
CC_file=""
if [ $SOURCE_CC_FILES != "NONE" ] && [ $SOURCE_CC_FILES != "N/A" ] && [ $SOURCE_CC_FILES != 0 ] && [ $SOURCE_CC_FILES != N ]; then
    CC=1;
    CC_file="all_CCsubs_languages.ismt";
fi

checkFileExist()
{   
   check_fileArr=( "$@" )
   for check_file in "${check_fileArr[@]}"; do
      if [ ! -f $check_file ]; then
        echo "File Not Produce Expected: $check_file"
        exit 1
      fi
    done
}



langs=();
#AUDIO REPACKAGING
for afile in $(cat $SOURCE_FILE_LIST |grep -e "AUD_"); do
    lang=eng
    #afile=${afile#*=}

    out_file=$(basename ${afile/.mp4/.isma})
    
    if [[ $out_file == AUD_* ]];
    then   
      #convert to lower case since mp4split support 3 code in lower case
      lang="$(tr [A-Z] [a-z] <<< "$lang")"
                
      $MP4SPLIT $LIC_KEY --brand piff -o ${out_file}  ${afile#*=} --track_language=$lang

      checkFileExist ${out_file}
                
      if [ "$?" = 0 ]; then
          echo "JOBID:$rand $afile packaged successfully." >>$LOG
                               
          if [ "$DRM" = 1 ]; then
                
              $MP4SPLIT $LIC_KEY --brand piff -o ${out_file}_pr.isma \
                                 --iss.key=$KID:$CEK \
                                 --iss.license_server_url=$LAURL \
                                 ${out_file}
              checkFileExist ${out_file}_pr.isma
              mv ${out_file}_pr.isma ${out_file} >/dev/null
          fi
      else
            echo "JOBID:$rand $afile PACKAGING ERROR. " >>$LOG
            echo "JOBID:$rand $afile PACKAGING ERROR. " >$TECH_META_URI
            rm ./*
            exit 1
      fi
      langs+=("$lang")
    fi
done
 
#Making unique langs
langs=($(tr ' ' '\n' <<<"${langs[@]}" | awk '!u[$0]++' | tr '\n' ' '))
 
for i in ${langs[@]}; do
     lFiles=()
     for bfile in $(cat $SOURCE_FILE_LIST | grep -e "AUD_"); do
        l=en
        #bfile=${bfile#*=}

        out_file=$(basename ${bfile/.mp4/.isma})
        if [[ $out_file == AUD_* ]];
        then   
          lFiles+=("$out_file")
        fi
     done
    echo lang $i with lFiles ${lFiles[@]}
 
    $MP4SPLIT $LIC_KEY --brand piff -o all_audios_$i.isma ${lFiles[@]}  --track_language=$i >/dev/null

    checkFileExist all_audios_$i.isma
done
 
 
$MP4SPLIT $LIC_KEY --brand piff -o all_audio_languages.isma $(ls -1 all_audios*.isma) >/dev/null

checkFileExist all_audio_languages.isma             
 
#VIDEO REPACKAGING
for vfile in $(cat $SOURCE_FILE_LIST |grep -e "AEG_"); do
    out_file=${vfile##*/}
    out_file=$(basename ${out_file/.mp4/.ismv})
    if [[ $out_file == AEG_* ]];
    then             
      $MP4SPLIT $LIC_KEY --brand piff -o ${out_file} ${vfile}  >/dev/null
                
      if [ "$DRM" = 1 ]; then 
          $MP4SPLIT $LIC_KEY --brand piff -o ${out_file}_pr.ismv \
                             --iss.key=$KID:$CEK \
                             --iss.license_server_url=$LAURL \
                             ${out_file} >/dev/null
          
          checkFileExist ${out_file}_pr.ismv
          mv ${out_file}_pr.ismv  ${out_file}
      fi
      checkFileExist ${out_file}
    fi
done
 
#####START PACKAGE MANIFEST
allCCFile=" ";  
#CC REPACKAGING  SRT -> TTML -> ISMT
if [ "$CC" = 1 ]; then
    #PROCESSING CC
    for ccfile in $(cat $SOURCE_CC_FILES |grep -e ".vtt$"); do

        out_file=${ccfile##*/}
        out_file=$(basename ${out_file/.vtt/.ttml})

        #convert to temp ttml
        $MP4SPLIT $LIC_KEY -o ${out_file}  ${ccfile#*=}  --track_language=eng >/dev/null
                             
        checkFileExist ${out_file} 
                             
                             
        #convert to istm
        $MP4SPLIT $LIC_KEY -o ${out_file/.ttml/.ismt} ${out_file} --track_language=eng >/dev/null
                             
        checkFileExist ${out_file/.ttml/.ismt}
    done
              
    #aggregate all ismt
    $MP4SPLIT $LIC_KEY -o all_CCsubs_languages.ismt $(ls -1 *.ismt) >/dev/null
                             
    checkFileExist all_CCsubs_languages.ismt
    allCCFile=" all_CCsubs_languages.ismt "
fi               

    $MP4SPLIT $LIC_KEY -o $manifest_name"_dash.ism" \
                          $(ls *.ismv) \
                          $allCCFile \
                          all_audio_languages.isma >/dev/null

    $MP4SPLIT $LIC_KEY -o $manifest_name"_hls.ism" \
                          $hlsManifestArgs \
                          $(ls *.ismv) \
                          $allCCFile \
                          all_audio_languages.isma >/dev/null


checkFileExist $manifest_name"_dash.ism" $manifest_name"_hls.ism"

mv *.ism* $DESTINATION_FOLDER/
exit $?
