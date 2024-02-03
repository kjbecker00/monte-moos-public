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
TEMP_INPUT_FILE=$(temp_filename ${INPUT_FILE})
TEMP_INPUT_FILE2=$(temp_filename ${INPUT_FILE2})
# Copy the file so we don't edit any of the originals
cp "$INPUT_FILE" "$TEMP_INPUT_FILE" || vexit "Error copying $INPUT_FILE to $TEMP_INPUT_FILE" 1
cp "$INPUT_FILE2" "$TEMP_INPUT_FILE2" || vexit "Error copying $INPUT_FILE2 to $TEMP_INPUT_FILE2" 1

# Add newline if not present
[ -n "$(tail -c1 $TEMP_INPUT_FILE)" ] && printf '\n' >>$TEMP_INPUT_FILE
[ -n "$(tail -c1 $TEMP_INPUT_FILE2)" ] && printf '\n' >>$TEMP_INPUT_FILE2

# Cat the files together (file 2 appended to end of file 1)
echo "${breakpoint}" >>"$TEMP_INPUT_FILE"
cat "$TEMP_INPUT_FILE2" >>"$TEMP_INPUT_FILE"

# echo "Press any key to continue, or Ctrl-C to cancel."
# read -n 1 -s

#--------------------------------------------------------------
#  Part 4: Mergeing
#--------------------------------------------------------------
# To merge we cat the files and then run consolodate_queue.sh
# Output uses different suffix to prevent overwriting if INPUT_FILE or INPUT_FILE2
# are the same as output_filename
# vecho "output= ${OUTPUT_FILENAME}.out.tmp" 1
# vecho "input= $TEMP_INPUT_FILE" 1
TEMP_OUTPUT=$(temp_filename ${OUTPUT_FILENAME}).out
${MONTE_MOOS_BASE_DIR}/scripts/consolodate_queue.sh --output=$TEMP_OUTPUT "$TEMP_INPUT_FILE" -b="$breakpoint" $FLOW_DOWN_ARGS #>/dev/null
EXIT_CODE=$?

# Remove the temp file
rm "$TEMP_INPUT_FILE" 2>/dev/null
rm "$TEMP_INPUT_FILE2" 2>/dev/null
mkdir -p $(dirname "$OUTPUT_FILENAME")
mv "$TEMP_OUTPUT" "$OUTPUT_FILENAME" || vexit "Error moving $TEMP_OUTPUT to $OUTPUT_FILENAME" 1

# Check for errors
if [[ $EXIT_CODE -ne 0 ]]; then
    vexit "Error in consolodate_queue.sh, exited with code $EXIT_CODE " 1
fi
