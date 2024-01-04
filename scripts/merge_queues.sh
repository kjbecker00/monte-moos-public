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
        exit 0;
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

# Copy the file so we don't edit any of the originals
cp "$INPUT_FILE" "${INPUT_FILE}.temp" || vexit "Error copying $INPUT_FILE to ${INPUT_FILE}.temp" 1
cp "$INPUT_FILE2" "${INPUT_FILE2}.temp" || vexit "Error copying $INPUT_FILE2 to ${INPUT_FILE2}.temp" 1

# Add newline if not present
[ -n "$(tail -c1 ${INPUT_FILE}.temp)" ] && printf '\n' >>${INPUT_FILE}.temp
[ -n "$(tail -c1 ${INPUT_FILE2}.temp)" ] && printf '\n' >>${INPUT_FILE2}.temp

# Cat the files together (file 2 appended to end of file 1)
echo "${breakpoint}" >> "${INPUT_FILE}.temp"
cat "$INPUT_FILE2.temp" >> "${INPUT_FILE}.temp"

# echo "Press any key to continue, or Ctrl-C to cancel."
# read -n 1 -s

#--------------------------------------------------------------
#  Part 4: Mergeing
#--------------------------------------------------------------
# To merge we cat the files and then run consolodate_queue.sh
# Output uses different suffix to prevent overwriting if INPUT_FILE or INPUT_FILE2
# are the same as output_filename
# vecho "output= ${OUTPUT_FILENAME}.out.tmp" 1
# vecho "input= ${INPUT_FILE}.temp" 1
${MONTE_MOOS_BASE_DIR}/scripts/consolodate_queue.sh --output=${OUTPUT_FILENAME}.out.tmp "${INPUT_FILE}.temp" -b="$breakpoint" $FLOW_DOWN_ARGS #>/dev/null
EXIT_CODE=$?



# Remove the temp file
rm "${INPUT_FILE}.temp" 2> /dev/null
rm "${INPUT_FILE2}.temp" 2> /dev/null
mv "${OUTPUT_FILENAME}.out.tmp" "$OUTPUT_FILENAME"

# Check for errors
if [[ $EXIT_CODE -ne 0 ]]; then
    vexit "Error in consolodate_queue.sh, exited with code $EXIT_CODE " 1
fi


