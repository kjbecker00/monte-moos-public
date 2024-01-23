#!/bin/bash
# Kevin Becker Nov 17 2023

HOST_QUEUE_FILE="host_job_queue.txt"
MY_QUEUE_FILE="${MYNAME}_job_queue.txt"
QUEUE_FILE=""
HOSTLESS="no"
ME="select_queue_file.sh"
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [options]         "
        echo "                                                          "
        echo " Selects a queue file to use. First, tries to pull a      "
        echo " client-specific queue file (myname_queue_file.txt) from  "
        echo " the host. If that fails, it tries to pull the host's     "
        echo " queue file. If that fails, it tries to use a local file. "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --nohost, -nh Only use local files, don't attempt to pull"
        echo "               a new queue file from the host."
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
    elif [[ -f "${CARLO_DIR_LOCATION}/$MY_QUEUE_FILE" ]]; then
        echo "${CARLO_DIR_LOCATION}/$MY_QUEUE_FILE"
        exit 0
    elif [[ -f "${CARLO_DIR_LOCATION}/$HOST_QUEUE_FILE" ]]; then
        echo "${CARLO_DIR_LOCATION}/$HOST_QUEUE_FILE"
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
vecho "Attempting to pull $MY_QUEUE_FILE from host using ${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/${MY_QUEUE_FILE}.enc" 1
/${MONTE_MOOS_BASE_DIR}/client_scripts/pull_from_host.sh -q "${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/${MY_QUEUE_FILE}.enc" >/dev/null
if [[ $? -eq 0 ]]; then
    INCOMING_FILE="${MY_QUEUE_FILE}"
else 
    vecho "Attempting to pull $HOST_QUEUE_FILE from host using ${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/${HOST_QUEUE_FILE}.enc" 1
    /${MONTE_MOOS_BASE_DIR}/client_scripts/pull_from_host.sh -q "${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/${HOST_QUEUE_FILE}.enc"  >/dev/null 
    [[ $? -eq 0 ]] || { vexit "unable to pull $MY_QUEUE_FILE or $HOST_QUEUE_FILE from host" 5 ; }
    INCOMING_FILE="${HOST_QUEUE_FILE}"
fi

# Ensure there was a prior version of the INCOMING_FILE before running mv
[[ ! -f "${INCOMING_FILE}" ]] && { touch "${INCOMING_FILE}" ; }
mv "${INCOMING_FILE}" ".old_${INCOMING_FILE}" 2> /dev/null
/${MONTE_MOOS_BASE_DIR}/scripts/encrypt_file.sh ${INCOMING_FILE}.enc >/dev/null 
# Remove the encrypted version of the file
rm "${INCOMING_FILE}.enc" 2> /dev/null

# Merges the two files together into .temp_queue.txt, then overwrirtes the old file.
consolodate_queue_flags=" --first_desired --max_actual "
/${MONTE_MOOS_BASE_DIR}/scripts/merge_queues.sh --output=.temp_queue.txt $INCOMING_FILE ".old_${INCOMING_FILE}" $consolodate_queue_flags #>/dev/null
rm ".old_${INCOMING_FILE}" 2> /dev/null
mv ".temp_queue.txt" "${INCOMING_FILE}" 2> /dev/null
echo "$INCOMING_FILE" 
exit 0

