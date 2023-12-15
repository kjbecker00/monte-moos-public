#!/bin/bash
# Kevin Becker Nov 17 2023

MYNAME=$(cat myname.txt)
VERBOSE=0
HOST_QUEUE_FILE="host_job_queue.txt"
MY_QUEUE_FILE="${MYNAME}_job_queue.txt"
QUEUE_FILE=""
HOSTLESS="no"
ME=$(basename "$0")
txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() {
    echo "${txtred}${ME}: Error $1. Exit Code $2 ${txtrst}"
    exit "$2"
}

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [options]         "
        echo " Selects a queue file to use. Pulls from the host as well."
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --nohost, -nh Only use local files, don't pull from the host."
        exit 0
    elif [ "${ARGI}" = "-nh" -o "${ARGI}" = "--nohost" ]; then
        HOSTLESS="yes"
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        vexit "Bad Arg: $ARGI " 3
    fi
done

# If hostless, only look here
if [[ "$HOSTLESS" == "yes" ]]; then
    if [[ -f "$MY_QUEUE_FILE" ]]; then
        echo "$MY_QUEUE_FILE"
        exit 0
    elif [[ -f "$HOST_QUEUE_FILE" ]]; then
        echo "$HOST_QUEUE_FILE"
        exit 0
    else
        vexit "No queue file found at $MY_QUEUE_FILE or $HOST_QUEUE_FILE" 1
    fi
    exit 1 # should never get here, but as a backup
fi

# Remove old encrypted versions (prevents bugs)
rm "${MY_QUEUE_FILE}.enc" 2> /dev/null
rm "${HOST_QUEUE_FILE}.enc" 2> /dev/null

INCOMING_FILE="${MY_QUEUE_FILE}"

# Attempts to pull one of two files from the host
./client_scripts/pull_from_host.sh "https://oceanai.mit.edu/monte/clients/${MY_QUEUE_FILE}.enc" >/dev/null
if [[ $? -eq 0 ]]; then
    INCOMING_FILE="${MY_QUEUE_FILE}"
else 
    ./client_scripts/pull_from_host.sh "https://oceanai.mit.edu/monte/clients/${HOST_QUEUE_FILE}.enc"  >/dev/null 
    [[ $? -eq 0 ]] || { vexit "unable to pull $MY_QUEUE_FILE or $HOST_QUEUE_FILE from host" 5 ; }
    INCOMING_FILE="${HOST_QUEUE_FILE}"
fi

# Ensure there was a prior version of the INCOMING_FILE before running mv
[[ ! -f "${INCOMING_FILE}" ]] && { touch "${INCOMING_FILE}" ; }
mv "${INCOMING_FILE}" ".old_${INCOMING_FILE}" 2> /dev/null
./scripts/encrypt_file.sh ${INCOMING_FILE}.enc >/dev/null 


# Merges the two files together into .temp_queue.txt, then overwrirtes the old file
./scripts/merge_queues.sh --output=.temp_queue.txt -fd $INCOMING_FILE ".old_${INCOMING_FILE}" >/dev/null
rm ".old_${INCOMING_FILE}" 2> /dev/null
mv ".temp_queue.txt" "${INCOMING_FILE}" 2> /dev/null
echo "$INCOMING_FILE" 
exit 0

