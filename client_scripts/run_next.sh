#!/bin/bash
# Kevin Becker Jun 9 2023


HOSTLESS="no"
TO_UPDATE="no"
ALL_JOBS_OK="yes"
ME=$(basename "$0")
VERBOSE=0

probability_skip=25    # proability it skips the first available job
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
        echo " Pulls queue from oceanai, runs the next job, and publishes"
        echo " the results. "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --update, -u   update the repos                        "
        echo " --hostless, -nh run everything without the host          "
        exit 0
    elif [[ "${ARGI}" = "--update" || "${ARGI}" = "-u" ]]; then
        TO_UPDATE="yes"
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="yes"
    else
        vexit "Bad Arg: $ARGI " 3
    fi
done

# if it should update
if [[ "$TO_UPDATE" == "yes" ]]; then
    vecho "UPDATING..." 1
    # remove old cache files
    rm -f .built_dirs
    if [ -f .built_dirs ]; then
        rm .built_dirs
    fi
    if [ -f "bad_jobs.txt" ]; then
        ./scripts/list_bad_job.sh -d
    fi
fi

echo $(tput bold)"-------------------------------------------------------" $txtrst

#-------------------------------------------------------
#  Part 2: Get the host's job queue files and decrypts them
#-------------------------------------------------------
if [[ "$HOSTLESS" == "yes" ]]; then
    QUEUE_FILE=$(./client_scripts/select_queue_file.sh -nh)
else
    QUEUE_FILE=$(./client_scripts/select_queue_file.sh)
fi
[[ $? -eq 0 ]] || { vexit "unable to pull a queue file from host. Exiting..." 8 ; }
        

#-------------------------------------------------------
#  Part 3: Determine which job to run
#-------------------------------------------------------

output=$(./client_scripts/select_job.sh --queue_file="$QUEUE_FILE")
EXIT_CODE=$?
# Check the queue by observing the exit code

# 1: no jobs left
[[ $EXIT_CODE -ne 1 ]] || { echo "No jobs left to run..." ; exit 1; }
# 2: no jobs left, but still has bad jobs
[[ $EXIT_CODE -ne 2 ]] || { echo "No jobs left to run, $(txtred) but has bad jobs... $(txtrst)" exit 1;  }
# not zero: bad
[[ $EXIT_CODE -eq 0 ]] || { vexit "running ./client_scripts/select_job.sh returned exit code: $EXIT_CODE" 9; }

vecho "queue line: $output" 5
JOB_FILE=$(./scripts/read_queue.sh -l="$output"  -jf)
JOB_ARGS=$(./scripts/read_queue.sh -l="$output"  -ja)
RUNS_DES=$(./scripts/read_queue.sh -l="$output"  -rd)
RUNS_ACT=$(./scripts/read_queue.sh -l="$output"  -ra)
RUNS_LEFT=$((RUNS_DES - RUNS_ACT))


# Notifies user, updates numbers for local copy of queue
echo $(tput bold)"Running Job $JOB_FILE ($RUNS_LEFT runs left)" $txtrst
RUNS_LEFT=$((RUNS_LEFT - 1))
RUNS_ACT=$((RUNS_ACT + 1))

#-------------------------------------------------------
#  Part 4: Get the job dir
#-------------------------------------------------------
# seperate by / and get the first part
JOB_FILE_NAME=$(basename $JOB_FILE)
JOB_DIR_FULL=$(dirname ${JOB_FILE})
JOB_DIR=${JOB_DIR_FULL#*/}
KERBS=$(echo "$JOB_DIR_FULL" | cut -d '/' -f 1)
FILE="$KERBS.tar.gz.enc"

if [ -f "$FILE" ]; then
    rm "$FILE"
fi

if [ "$HOSTLESS" = "no" ]; then
    vecho "Getting job dirs..." 1
    vecho "./client_scripts/pull_from_host.sh \"https://oceanai.mit.edu/monte/clients/job_dirs/$FILE\"" 2
    ./client_scripts/pull_from_host.sh "https://oceanai.mit.edu/monte/clients/job_dirs/$FILE"
    EXIT_CODE=$?
    
    # Pull from host worked
    if [[ $EXIT_CODE -eq 0 ]]; then
        # Success, move encrypted file to job_dirs, decrypt it
        if [ ! -d "job_dirs" ]; then
            mkdir job_dirs
        fi
        vecho "Moving $FILE to job_dirs/..." 1
        mv "$FILE" job_dirs/
        vecho "Decrypting job_dirs/$FILE ..." 1
        if [[ -d job_dirs/$KERBS ]]; then
            vecho "Removing old job_dirs/$KERBS ..." 1
            rm -rf job_dirs/$KERBS
        fi
        if [[ ! -f "job_dirs/$FILE" ]]; then
            vexit "job_dirs/$FILE does not exist" 1
        fi
        ./scripts/encrypt_file.sh "job_dirs/$FILE" >/dev/null
        EXIT_CODE=$?
        if [[ $EXIT_CODE -ne 0 ]]; then
            vexit "encrypt_file.sh failed do decrypt file job_dirs/$FILE with code $EXIT_CODE" 7
        fi

        if [[ -d job_dirs/backup_$KERBS ]]; then
            mv job_dirs/backup_$KERBS job_dirs/$KERBS 
        fi
        if [[ ! -d job_dirs/$KERBS ]]; then
            vexit "after decrypting $FILE, job_dirs/$KERBS still does not exist" 1
        fi

    # Pull from host failed; network error. Use a local copy if it exists
    elif [[ $EXIT_CODE -eq 4 ]]; then
        secho "./client_scripts/pull_from_host https://oceanai.mit.edu/monte/clients/job_dirs/$FILE failed with code $EXIT_CODE. Checking for local copy..."
       
        # - - - - - - - - - - - - - - - - - - - - -
        # Network error
        if [ -f "job_dirs/$JOB_FILE" ]; then
            vecho "Local copy found. Running..." 1
        else
            ./scripts/list_bad_job.sh "${JOB_FILE}"
            vexit "local copy of $JOB_FILE does not exist. Adding to bad_jobs.txt..." 2
        fi
    # Other failure. Exit
    else
        vexit "./client_scripts/pull_from_host https://oceanai.mit.edu/monte/clients/job_dirs/$FILE failed with code $EXIT_CODE" 1
    fi
fi

#-------------------------------------------------------
#  Part 5: Run it!
#-------------------------------------------------------
if [ "$HOSTLESS" = "yes" ]; then
    vecho "./client_scripts/run_job.sh --job_file=\"$JOB_FILE\" --job_args=\"$JOB_ARGS\" -nh" 1
    ./client_scripts/run_job.sh --job_file="$JOB_FILE" --job_args="$JOB_ARGS" -nh
else
    vecho "./client_scripts/run_job.sh --job_file=\"$JOB_FILE\" --job_args=\"$JOB_ARGS\"" 1
    ./client_scripts/run_job.sh --job_file="$JOB_FILE" --job_args="$JOB_ARGS"
fi


EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    # checks if the job was stopped by ctrl-c
    if [[ $EXIT_CODE -ne 130 ]]; then
        ./scripts/list_bad_job.sh "${JOB_FILE}"
        vexit "run_job.sh failed with exit code: $EXIT_CODE" 2
    fi
    vexit "run_job.sh failed with exit code: $EXIT_CODE" 130
fi

# update the queue file (helpful if trying to run w/o a host)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s@^$JOB_FILE $JOB_ARGS.*@$JOB_FILE $JOB_ARGS $RUNS_DES $RUNS_ACT@" "$QUEUE_FILE"
else
    # Linux
    sed -i "s@^$JOB_FILE $JOB_ARGS.*@$JOB_FILE $JOB_ARGS $RUNS_DES $RUNS_ACT@" "$QUEUE_FILE"
fi

exit 0
