#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 01/05/2024
# Script: monte_pull_results.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="monte_pull_results.sh"
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh
INPUT_PATH=""
OUTPUT_PATH=""

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: KERBS/path-to/job_name [OPTIONS]     "
        echo "                                                      "
        echo "Pulls results for a job file from the cluster.        "
        echo "                                                      "
        echo "  KERBS/path-to/job_name should match what is in the  "
        echo "    queue file.                                       "
        echo "                                                      "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        if [[ -z $INPUT_PATH ]]; then
            INPUT_PATH="${ARGI}"
        # elif [[ -z $OUTPUT_PATH ]]; then
        #     OUTPUT_PATH="${ARGI}"
        else
	        vexit "Input ($INPUT_PATH) already set. Bad Arg: $ARGI" 1
        fi
    fi
done



if [[ -z $INPUT_PATH ]]; then
    vexit "No input path specified" 1
fi
# if [[ -z $OUTPUT_PATH ]]; then
#     OUTPUT_PATH="$DEFAULT_OUTPUT_PATH"
# fi

#--------------------------------------------------------------
#  Part 3: Get the results
#--------------------------------------------------------------
# Remove trailing / if it exists
INPUT_PATH=${INPUT_PATH%/}
vecho "INPUT_PATH=$INPUT_PATH" 1
# vecho "OUTPUT_PATH=$OUTPUT_PATH" 1

full_input_path=${MONTE_MOOS_WGET_BASE_DIR}/results/${INPUT_PATH}
vecho "full_input_path= $full_input_path" 1


cut_dirs=$(echo "${full_input_path}" | awk -F"/" '{print NF-1}')
cut_dirs=$((cut_dirs-1))


vecho "cut-dirs=$cut_dirs" 2
vecho "wget -r -nH -np --progress=bar --cut-dirs=$cut_dirs -R \"index*\" -X /results \"${MONTE_MOOS_HOST_URL_WGET}${full_input_path}/\"" 2
if [[ $VERBOSE -ge 2 ]]; then
    wget -r -nH -np --progress=bar --cut-dirs=$cut_dirs -R "index*" -X /results "${MONTE_MOOS_HOST_URL_WGET}${full_input_path}/"
else
    echo "Running wget..."
    wget -q -r -nH -np --progress=bar --cut-dirs=$cut_dirs -R "index*" -X /results "${MONTE_MOOS_HOST_URL_WGET}${full_input_path}/"
fi
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    vexit "wget failed with exit code $EXIT_CODE" $EXIT_CODE
fi

rm -f robots.txt
# mkdir -p $OUTPUT_PATH
# mv results $OUTPUT_PATH




