#!/bin/bash
# Kevin Becker, May 26 2023

# Script used to extract results from a job.
ME=$(basename "$0")
VERBOSE=0
LINK_TO_FILE=""
QUIET=0
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
    /${MONTE_MOOS_BASE_DIR}/scripts/secho.sh "${txtred}$ME: Error: $1. Exit Code $2 $txtrst"
    exit "$2"
}

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh INFO [OPTIONS]"
        echo "                                                          "
        echo " This is a script used to pull a given file from the host.    "
        echo " It's just a wrapper around wget with echo aound exit codes. "
        echo ""
        echo "Options:                                                   "
        echo " --help, -h  Show this help message                         "
        echo " --quiet, -q Don't secho anything                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" = "--quiet" || "${ARGI}" = "-q" ]]; then
        QUIET=1
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
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


#-------------------------------------------------------
#  Part 2: Checks
#-------------------------------------------------------
if [ -z $LINK_TO_FILE ]; then
    vexit "No file specified" 1
fi

vecho "pinging host: $MONTE_MOOS_HOSTNAME_SSH" 1
ping -c 1 "$MONTE_MOOS_HOSTNAME_SSH" >/dev/null 
# If first ping fails, try again
if [[ $? -eq 0 ]]; then
    sleep 1
    ping -c 5 "$MONTE_MOOS_HOSTNAME_SSH" >/dev/null 
    [[ $? -eq 0 ]] || { vexit "Cannot find host" 5 ; }
fi

vecho "Pulling file from host: $LINK_TO_FILE" 1


#-------------------------------------------------------
#  Part 3: Pull the file from the host
#-------------------------------------------------------

vecho "running wget -q $LINK_TO_FILE" 1
wget -q "$LINK_TO_FILE"
EXIT_CODE=$?
# Check for errors, print them out
if [[ $EXIT_CODE -ne 0 ]]; then
    vecho "wget $LINK_TO_FILE failed with code $EXIT_CODE" 2

    # - - - - - - - - - - - - - - - - - - - - -
    # Network error
    if [[ $EXIT_CODE -eq 4 ]]; then
        vexit "Network error. Check your connection." 4

    # - - - - - - - - - - - - - - - - - - - - -
    # Server error (no file exists on server)
    elif [[ $EXIT_CODE -eq 8 ]]; then # no file on server
        if [[ $QUIET -eq 1 ]]; then
            echo "${txtred}$ME: File $LINK_TO_FILE not found on server $txtrst"
            exit 1
        else
            vexit "File $LINK_TO_FILE not found on server" 1
        fi
    # - - - - - - - - - - - - - - - - - - - - -
    # Unknown error
    else
        vexit "wget -q $LINK_TO_FILE failed with code $EXIT_CODE" 2
    fi
else
    # No errors
    exit 0
fi