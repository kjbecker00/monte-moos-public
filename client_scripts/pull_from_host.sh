#!/bin/bash
# Kevin Becker, May 26 2023

# Script used to extract results from a job.
ME=$(basename "$0")
VERBOSE=0
LINK_TO_FILE=""

txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey
txtbld=$(tput bold)    # Bold
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() {
    ./scripts/secho.sh "${txtred}$ME: Error $1. Exit Code $2 $txtrst"
    exit "$2"
}

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh INFO [OPTIONS]"
        echo " This is a script used to pull a given file from the host.    "
        echo " with the current setup, it's a wrapper around wget. "
        echo "Options:                                                   "
        echo " --help, -h Show this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" =~ "--verbose=" || "${ARGI}" =~ "-v=" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        if [ -z $LINK_TO_FILE ]; then
            LINK_TO_FILE=$ARGI
        else
            vexit "Bad Arg: $ARGI " 1
        fi
    fi
done

if [ -z $LINK_TO_FILE ]; then
    vexit "No file specified" 1
fi


#-------------------------------------------------------
#  Part 2: Pull the file from the host
#-------------------------------------------------------
wget -q "$LINK_TO_FILE"
EXIT_CODE=$?
# Check for errors, print them out
if [[ $EXIT_CODE -ne 0 ]]; then
    vecho "wget $LINK_TO_FILE failed with code $EXIT_CODE" 1
    # - - - - - - - - - - - - - - - - - - - - -
    # Network error
    if [[ $EXIT_CODE -eq 4 ]]; then
        vexit "Network error. Check your connection." 4
        if [ -f "job_dirs/$JOB_FILE" ]; then
            vecho "Local copy found. Running..." 1
        else
            ./scripts/list_bad_job.sh "${JOB_FILE}"
            vexit "local copy of $JOB_FILE does not exist. Adding to bad_jobs.txt..." 2
        fi
    # - - - - - - - - - - - - - - - - - - - - -
    # Server error (no file exists on server)
    elif [[ $EXIT_CODE -eq 8 ]]; then # no file on server
        vecho "Job not found on server. Adding to bad_jobs.txt..." 1
        ./scripts/list_bad_job.sh "${JOB_FILE}"
    # - - - - - - - - - - - - - - - - - - - - -
    # Unknown error
    else
        vexit "wget https://oceanai.mit.edu/monte/clients/job_dirs/$FILE failed with code $EXIT_CODE" 1
    fi
else
    # No errors
    exit 0
fi