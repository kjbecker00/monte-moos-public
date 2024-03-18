#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 12/01/2023
# Script: merge_queues.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="merge_queues.sh"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

INPUT_FILE=""
INPUT_FILE2=""
FLOW_DOWN_ARGS=""
breakpoint="-------BREAKPOINT-------"
OUTPUT_FILENAME="merged_queue.txt"

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] queue_file_1.txt queue_file_2.txt"
        echo "                                                          "
        echo "This script takes in two queues and merges them together."
        echo "The two files are cat'd together and then consolodate_queue.sh"
        echo "is run to remove duplicates. "
        echo "                                                          "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo "    All other args are passed to consolodate_queue.sh "
        exit 0
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" = "--output="* || "${ARGI}" = "-o="* ]]; then
        OUTPUT_FILENAME="${ARGI#*=}"
    elif [[ "${ARGI}" = "-"* ]]; then
        FLOW_DOWN_ARGS="${FLOW_DOWN_ARGS} $ARGI"
    elif [ -z $INPUT_FILE ]; then
        INPUT_FILE=$ARGI
    elif [ -z $INPUT_FILE2 ]; then
        INPUT_FILE2=$ARGI
    else
        vexit "Bad Arg: $ARGI " 3
    fi
done

#--------------------------------------------------------------
#  Part 3: Pre-flight Checks
#--------------------------------------------------------------
if [[ ! -f $INPUT_FILE ]]; then
    vexit "File 1 does not exist: $INPUT_FILE" 1
fi
if [[ ! -f $INPUT_FILE2 ]]; then
    vexit "File 2 does not exist: $INPUT_FILE2" 1
fi

vecho "mergeing file 1: $INPUT_FILE and $INPUT_FILE2" 1
#--------------------------------------------------------------
#  Part 4: Cat files together
#--------------------------------------------------------------
TEMP_INPUT_FILE=$(temp_filename ${INPUT_FILE})
# Copy file 1 to the temp file
cat $INPUT_FILE >> $TEMP_INPUT_FILE
# Add breakpoint
echo "${breakpoint}" >>"$TEMP_INPUT_FILE"
# Copy file 2 to the temp file
cat $INPUT_FILE2 >> $TEMP_INPUT_FILE


#--------------------------------------------------------------
#  Part 4: Consolodate the queue
#--------------------------------------------------------------
# Removes duplicates, adds desired_runs, takes max act_runs
TEMP_OUTPUT=$(temp_filename ${OUTPUT_FILENAME}).out
rm -f "$TEMP_OUTPUT"
vecho "Consolodating queue $TEMP_INPUT_FILE to $TEMP_OUTPUT..." 1

${MONTE_MOOS_BASE_DIR}/scripts/consolodate_queue.sh --output=$TEMP_OUTPUT "$TEMP_INPUT_FILE" -b="$breakpoint" $FLOW_DOWN_ARGS #>/dev/null
EXIT_CODE=$?
# Check for errors
if [[ $EXIT_CODE -ne 0 ]]; then
    vexit "Error in consolodate_queue.sh, exited with code $EXIT_CODE " 1
fi

# Remove the temp file
rm "$TEMP_INPUT_FILE" 2>/dev/null
mkdir -p $(dirname "$OUTPUT_FILENAME")
mv "$TEMP_OUTPUT" "$OUTPUT_FILENAME" || vexit "Error moving $TEMP_OUTPUT to $OUTPUT_FILENAME" 1

vecho "output to $OUTPUT_FILENAME" 1
