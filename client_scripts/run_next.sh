#!/bin/bash
# Kevin Becker Jun 9 2023

HOSTLESS="no"
TO_UPDATE="no"
ME="run_next.sh"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [options]         "
        echo "                                                          "
        echo " Pulls queue from the host (if desired), select the next  "
        echo " job, update the base directory of that job, runs said    "
        echo " job, and publishes the results.                          "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --update, -u    update the repos                         "
        echo " --hostless, -nh run everything without the host. So no  "
        echo "                 pulling from the host, no updating the   "
        echo "                 queue file, and no publishing results    "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" = "--update" || "${ARGI}" = "-u" ]]; then
        TO_UPDATE="yes"
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="yes"
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        vexit "Bad Arg: $ARGI " 3
    fi
done
echo $(tput bold)"-------------------------------------------------------" $txtrst

#-------------------------------------------------------
# If it should update the moos-dirs
#-------------------------------------------------------
if [[ "$TO_UPDATE" == "yes" ]]; then
    secho "Updating all repos..." 1
    # remove old cache files
    rm -f .built_dirs
    if [ -f .built_dirs ]; then
        rm .built_dirs
    fi
fi

#-------------------------------------------------------
#  Part 2: Get the host's job queue files and decrypts them
#-------------------------------------------------------
if [[ "$HOSTLESS" == "yes" ]]; then
    OUTPUT=$(/${MONTE_MOOS_BASE_DIR}/client_scripts/select_queue_file.sh -nh)
else
    OUTPUT=$(/${MONTE_MOOS_BASE_DIR}/client_scripts/select_queue_file.sh)
fi
[[ $? -eq 0 ]] || { vexit "unable to pull a queue file (hostless=$HOSTLESS). Exiting..." 8; }

QUEUE_FILE=$(echo "$OUTPUT" | tail -n 1)
echo "$OUTPUT" | awk '{if (a) print a; a=b; b=c; c=$0}'

FULL_QUEUE_FILE=${CARLO_DIR_LOCATION}/$QUEUE_FILE
vecho "Using queue file: ${FULL_QUEUE_FILE}" 1

#-------------------------------------------------------
#  Part 3: Determine which job to run
#-------------------------------------------------------
output=$(/${MONTE_MOOS_BASE_DIR}/client_scripts/select_job.sh --queue_file="$FULL_QUEUE_FILE")
EXIT_CODE=$?
# Check the queue by observing the exit code
# 1: no jobs left
[[ $EXIT_CODE -ne 1 ]] || {
    echo "No jobs left to run..."
    exit 1
}
# 2: no jobs left, but still has bad jobs
[[ $EXIT_CODE -ne 2 ]] || {
    echo "No jobs left to run, but has bad jobs... "
    exit 1
}
# not zero: bad
[[ $EXIT_CODE -eq 0 ]] || { vexit "running /${MONTE_MOOS_BASE_DIR}/client_scripts/select_job.sh --queue_file="$FULL_QUEUE_FILE" returned exit code: $EXIT_CODE" 9; }

vecho "queue line: $output" 5
JOB_FILE=$(/${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh -l="$output" -jf)
JOB_ARGS=$(/${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh -l="$output" -ja)
RUNS_DES=$(/${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh -l="$output" -rd)
RUNS_ACT=$(/${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh -l="$output" -ra)
RUNS_LEFT=$((RUNS_DES - RUNS_ACT))

vecho "Initial run_act=$RUNS_ACT" 1

#-------------------------------------------------------
#  Part 4: Get the job dir
#-------------------------------------------------------
vecho "JOB_FILE: $JOB_FILE" 5

JOB_DIR_NAME=$(job_dirname "$JOB_FILE")
JOB_PATH=$(job_path "$JOB_FILE")
# name of the zipped and encrypted job_dir
JOB_DIR_FILE="$JOB_DIR_NAME.tar.gz.enc"
# FULL path, to the job file
FULL_JOB_PATH=${CARLO_DIR_LOCATION}/.temp_job_dirs/$JOB_PATH

# Notifies user, updates numbers for local copy of queue
echo $(tput bold)"Running Job $JOB_FILE ($RUNS_LEFT runs left)" $txtrst
RUNS_LEFT=$((RUNS_LEFT - 1))
RUNS_ACT=$((RUNS_ACT + 1))
vecho "New run_act=$RUNS_ACT" 1

#-------------------------------------------------------
#  Part 4B: Update the job file by pulling the job dir from the host
#-------------------------------------------------------
cd "${CARLO_DIR_LOCATION}" || vexit "cd ${CARLO_DIR_LOCATION} failed" 1
if [ "$HOSTLESS" = "no" ]; then

    # Update the queue file
    vecho "Getting job dirs..." 1
    vecho "/${MONTE_MOOS_BASE_DIR}/client_scripts/pull_from_host.sh \"${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/job_dirs/$JOB_DIR_FILE\"" 2
    /${MONTE_MOOS_BASE_DIR}/client_scripts/pull_from_host.sh "${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_WGET_BASE_DIR}/clients/job_dirs/$JOB_DIR_FILE"
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        vexit "/${MONTE_MOOS_BASE_DIR}/client_scripts/pull_from_host.sh ${MONTE_MOOS_HOST_URL_WGET}${MONTE_MOOS_HOST_CLIENT_DIR}/job_dirs/$JOB_DIR_NAME failed with code $EXIT_CODE" 1
    fi

    # Success! Move encrypted file to .temp_job_dirs, decrypt it
    if [ ! -d ".temp_job_dirs" ]; then
        mkdir .temp_job_dirs
    fi

    vecho "Moving $JOB_DIR_FILE to .temp_job_dirs/..." 1
    mv "$JOB_DIR_FILE" .temp_job_dirs/

    # Decrypt
    vecho "Decrypting .temp_job_dirs/$JOB_DIR_FILE ..." 1
    monte_decrypt.sh ".temp_job_dirs/$JOB_DIR_FILE" -o -d
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        vexit "monte_decrypt.sh failed do decrypt file .temp_job_dirs/$JOB_DIR_FILE -o -d with code $EXIT_CODE" 7
    fi

    # Decompress
    vecho "Decompressing .temp_job_dirs/$JOB_DIR_NAME.tar.gz ..." 1
    monte_decompress.sh ".temp_job_dirs/$JOB_DIR_NAME.tar.gz" -o -d
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        vexit "monte_decrypt.sh failed do decrypt file .temp_job_dirs/$JOB_DIR_NAME.tar.gz -o -d with code $EXIT_CODE" 7
    fi

    # Check that the dir now exists
    if [[ ! -d "${CARLO_DIR_LOCATION}/.temp_job_dirs/$JOB_DIR_NAME" ]]; then
        vexit "after decrypting $JOB_DIR_NAME, ${CARLO_DIR_LOCATION}/.temp_job_dirs/$JOB_DIR_NAME still does not exist" 1
    fi

fi

#-------------------------------------------------------
#  Part 5: Run the job!
#-------------------------------------------------------
if [ "$HOSTLESS" = "yes" ]; then
    vecho "monte_run_job.sh --job_file=\"$FULL_JOB_PATH\" --job_args=\"$JOB_ARGS\" -nh" 1
    monte_run_job.sh --job_file="$FULL_JOB_PATH" --job_args="$JOB_ARGS" -nh
else
    vecho "monte_run_job.sh --job_file=\"$FULL_JOB_PATH\" --job_args=\"$JOB_ARGS\"" 1
    monte_run_job.sh --job_file="$FULL_JOB_PATH" --job_args="$JOB_ARGS"
fi

EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    # checks if the job was stopped by ctrl-c
    if [[ $EXIT_CODE -ne 130 ]]; then
        /${MONTE_MOOS_BASE_DIR}/client_scripts/list_bad_job.sh "${JOB_PATH} ${JOB_ARGS}"
        vexit "monte_run_job.sh failed with exit code: $EXIT_CODE. " 2
    fi
    vexit "Detected ctrl-c. Exiting..." 130
fi

#-------------------------------------------------------
#  Part 6: Update the queue file
#-------------------------------------------------------
vecho "Updating queue file $FULL_QUEUE_FILE" 1
vecho " $JOB_PATH $JOB_ARGS $RUNS_DES $RUNS_ACT" 1
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s@^$JOB_PATH $JOB_ARGS.*@$JOB_PATH $JOB_ARGS $RUNS_DES $RUNS_ACT@" "$FULL_QUEUE_FILE"
    vecho "sed -i '' \"s@^$JOB_PATH $JOB_ARGS.*@$JOB_PATH $JOB_ARGS $RUNS_DES $RUNS_ACT@\" \"$FULL_QUEUE_FILE\"" 1
else
    # Linux
    sed -i "s@^$JOB_PATH $JOB_ARGS.*@$JOB_PATH $JOB_ARGS $RUNS_DES $RUNS_ACT@" "$FULL_QUEUE_FILE"
fi

exit 0
