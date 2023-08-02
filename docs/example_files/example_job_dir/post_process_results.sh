#!/bin/bash
#-------------------------------------------------------------- 
# Author: Kevin Becker
# Date: 07/13/2023
# Script: post_process_results.sh
#-------------------------------------------------------------- 
# Part 1: Convenience functions, variables
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
        echo " --help, -h                    Show this help message     " 
        echo " --job_file=[config_file]      add the job file vars to   "
        echo "                               this script's namespace    "
        echo " --local_results_dir=[results_dir]  directory where this  " 
        echo "                               script should save all the "
        echo "                               results.                   "
        echo "  --verbose=num, -v=num or --verbose, -v                  "
        echo "                               Set verbosity              "
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
#  Part 3: Post-process the files on the *local* machine
#          NOTE: be sure to save your results to the 
#                directory $RESULTS_DIR
#
# Add or remove as much as you want below this line,
# although its a good idea to keep all of part 3
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
# Copy alog files to results/web (published to internet)
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Shoreside alogs
cp $SHORE_ALOG $RESULTS_DIR/web
if [[ $? -ne 0 ]]; then
    vexit "Error, could not copy $SHORE_ALOG to $RESULTS_DIR" 1
fi
# Remaining alogs
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
echo "Ran on host:  $(hostname)" > $RESULTS_DIR/machine_info.txt
echo "Username:     $(id -un)"     >> $RESULTS_DIR/machine_info.txt




#--------------------------------------------------------------------------------------------------------------
# For most missions, (unless realy private) EDIT BELOW THIS LINE!
#--------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------
#  Part 4: 
# More configurable options, which likely change from 
# job to job.
#-------------------------------------------------------

#-------------------------------------------------------
# Write the outcome of a job to a csv. Used to generate
# Plots. Here is an example of what you can do:
#-------------------------------------------------------
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy what we want from the alog
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -

MOOS_KEY="SCORE"
MOOS_KEY2="CONFIG_VAR_1"
MOOS_KEY3="CONFIG_VAR_2"

output=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY} --final -q)
output2=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY2} --final -q)
output3=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY3} --final -q)

MOOS_VALUE=$(echo $output | awk '{print $4}')
MOOS_VALUE2=$(echo $output2 | awk '{print $4}')
MOOS_VALUE3=$(echo $output3 | awk '{print $4}')

KEYS="Time (s),Config Var 1,Config Var 2"
VALUES="$MOOS_VALUE,$MOOS_VALUE2,$MOOS_VALUE3"

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Write to the main output file: results.csv
# Note: Save more variables than you think you may need.
#       It is much easier to re-plot from a compiled
#       csv than it is to re-scrape the alogs!
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
echo "$KEYS" >> $RESULTS_DIR/results.csv
echo "$VALUES" >> $RESULTS_DIR/results.csv
