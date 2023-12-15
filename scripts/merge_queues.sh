#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 12/01/2023
# Script: merge_queues.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi }
wecho() { echo ${txtylw}"$ME: $1" ${txtrst}; }
vexit() { echo ${txtred}"$ME: Error $1. Exit Code $2" ${txtrst} ; exit "$2" ; }
INPUT_FILE=""
INPUT_FILE2=""
FLOW_DOWN_ARGS=""
#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] queue_file_1.txt queue_file_2.txt"
        echo "This script takes in two queues and merges them together."
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo "    All other args are passed to consolodate_queue.sh "
        exit 0;
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" = "--output="* || "${ARGI}" = "-o="* ]]; then
        OUTPUT_FILENAME="${ARGI#*=}"
    else
        if [ -z $INPUT_FILE ]; then
            INPUT_FILE=$ARGI
        elif [ -z $INPUT_FILE2 ]; then
            INPUT_FILE2=$ARGI
        else
	        FLOW_DOWN_ARGS="${FLOW_DOWN_ARGS} $ARGI"
        fi
    fi
done


# Check that the files exist
if [[ ! -f "$INPUT_FILE" || ! -f "$INPUT_FILE2" ]]; then
    vexit "Check input files, one or more may not exist" 1
fi

# Copy the file so we don't edit any of the originals
cp "$INPUT_FILE" ".temp_${INPUT_FILE}"

# To merge we cat the files and then run consolodate_queue.sh
cat "$INPUT_FILE2" >> $".temp_${INPUT_FILE}"
./scripts/consolodate_queue.sh --output=$OUTPUT_FILENAME $".temp_${INPUT_FILE}" $FLOW_DOWN_ARGS >/dev/null
EXIT_CODE=$?

# Remove the temp file
rm ".temp_${INPUT_FILE}" 2> /dev/null

# Check for errors
if [[ $EXIT_CODE -ne 0 ]]; then
    vexit "Error in consolodate_queue.sh, exited with code $EXIT_CODE " 1
fi


