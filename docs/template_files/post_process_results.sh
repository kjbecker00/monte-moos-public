#!/bin/bash
#-------------------------------------------------------------- 
# Author: Kevin Becker
# Date: 08/13/2023
# Tempalate sript: post_process_results.sh
#-------------------------------------------------------------- 
# Part 1: Convenience functions
#-------------------------------------------------------------- 
ME=$(basename "$0")
VERBOSE=0
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $(tput sgr0); fi }

RESULTS_DIR=""
#-------------------------------------------------------
#  Part 2: Handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--local_results_dir=" ]]; then
        RESULTS_DIR="${ARGI#*=}"
    else
        echo "Unrecognized option: $ARGI"
        exit 1
    fi
done

. ${JOB_FILE}
mkdir $RESULTS_DIR/web



#-------------------------------------------------------
# Part 3: Write the result of one run to a csv.
#-------------------------------------------------------
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get what we want from the alog
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Find the shore alog file
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
SHORE_ALOG=$(find "moos-dirs/${SHORE_REPO}/${SHORE_MISSION}"/*SHORE*/*.alog 2>/dev/null | head -1)
if [ -z $SHORE_ALOG ]; then
    SHORE_ALOG=$(find "moos-dirs/${SHORE_REPO}/${SHORE_MISSION}"/*/*.alog 2>/dev/null | head -1)
    [ $? -eq 0 ] || { vexit "No alog found in $PWD/$SHORE_MISSION_DIR" 2; }
fi
if [ -z $SHORE_ALOG ]; then
    echo "Error, could not find shore alog file. Exiting..."
    exit 1
fi
MOOS_KEY="SOME_VARIABLE"
MOOS_KEY2="OTHER_VARIABLE"

MOOS_VALUE=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY} --final -q --v)
MOOS_VALUE2=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY2} --final -q --v)

if [[ -z "$MOOS_VALUE" || -z "$MOOS_VALUE2" ]]; then
   echo "Error, unable to find all variables. Exiting..."
   exit 2
fi

KEYS="${MOOS_KEY},${MOOS_KEY2}"
VALUES="$MOOS_VALUE,$MOOS_VALUE2"


#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Write to the main output file: results.csv
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "$KEYS" >> $RESULTS_DIR/results.csv
echo "$VALUES" >> $RESULTS_DIR/results.csv





#-------------------------------------------------------
#  Part 4: Post-process the files on the *local* machine
#          NOTE: be sure to direct all files to the
#          directory $RESULTS_DIR
#-------------------------------------------------------
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy other alog files
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
ALOG_FILES=""
for file in "moos-dirs/${SHORE_REPO}/${SHORE_MISSION}"/*/*.alog; do
    cp "$file" "$RESULTS_DIR/web"
    ALOG_FILES="$ALOG_FILES $file"
done
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Generate a track, showing each vehicle
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
scripts/alog2image.py -a -i --fname="${RESULTS_DIR}/web/track.png" $ALOG_FILES
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Error, could not run alog2image.py with shore alog $SHORE_ALOG Exit code: $EXIT_CODE. Continuing..."
fi
wait
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Include some informaiton on the client
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Ran on host:  $(cat myname.txt)" > $RESULTS_DIR/machine_info.txt
echo "Username:     $(id -un)"     >> $RESULTS_DIR/machine_info.txt