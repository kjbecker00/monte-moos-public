#!/bin/bash
#-------------------------------------------------------------- 
# Author: Kevin Becker
# Date: 07/13/2023
# Script: post_process_results.sh
#-------------------------------------------------------------- 
# Part 1: Convenience functions
#-------------------------------------------------------------- 
ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green                     
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }

RESULTS_DIR=""
#-------------------------------------------------------
#  Part 2: Handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --dir=[output_directory] "
        echo "Options:                                                  " 
        echo " --help, -h Show this help message                        " 
        echo " --job_file=[config_file]  add the job file vars to this script's namespace           "
        echo " --local_results_dir=[results_dir]  directory where the results reside          " 
        exit 0;
    elif [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--local_results_dir=" ]]; then
        RESULTS_DIR="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        echo "Unrecognized option: $ARGI"
        exit 1
    fi
done
# Read job file
if [ -z $JOB_FILE ]; then
    vecho "Warning, no job file set" 1
else
    . ${JOB_FILE}
fi
# Generate web directory locally
mkdir $RESULTS_DIR/web




#-------------------------------------------------------
# Part 3: Write the outcome of a job to a csv. Used to generate
# Plots. Here is an example of what you can do:
#-------------------------------------------------------
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy what we want from the alog
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -

MOOS_KEY="WPT_EFF_DIST_ALL"
MOOS_KEY2="WPT_EFF_TIME_ALL"
MOOS_KEY3="CYCLE_INDEX"
MOOS_KEY4="WPT_INDEX"

# output=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY} --final -q --v)
# output2=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY2} --final -q)
# output3=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY3} --final -q)
# output4=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY4} --final -q)

MOOS_VALUE=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY} --final -q --v)
MOOS_VALUE2=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY2} --final -q --v)
MOOS_VALUE3=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY3} --final -q --v)
MOOS_VALUE4=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY4} --final -q --v)

if [[ -z "$MOOS_VALUE" || -z "$MOOS_VALUE2" || -z "$MOOS_VALUE3" || -z "$MOOS_VALUE4" ]]; then
   echo "Error, unable to find all variables. Exiting..."
   exit 2
fi

KEYS="${MOOS_KEY},${MOOS_KEY2},${MOOS_KEY3},${MOOS_KEY4}"
VALUES="$MOOS_VALUE,$MOOS_VALUE2,$MOOS_VALUE3,$MOOS_VALUE4"
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Write to the main output file: results.csv
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "$KEYS" >> $RESULTS_DIR/results.csv
echo "$VALUES" >> $RESULTS_DIR/results.csv





#-------------------------------------------------------
#  Part 4: Post-process the files on the *local* machine
#          NOTE: be sure to save your results to the 
#                directory $RESULTS_DIR
#
# Add or remove as much as you want below this line
#-------------------------------------------------------
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
# Good idea to include some informaiton on the client
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "Ran on host:  $(cat myname.txt)" > $RESULTS_DIR/machine_info.txt
echo "Username:     $(id -un)"     >> $RESULTS_DIR/machine_info.txt
