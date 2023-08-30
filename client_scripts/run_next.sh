#!/bin/bash
# Kevin Becker Jun 9 2023
QUEUE_FILE="host_job_queue.txt"
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
    ./scripts/secho.sh "${txtred}${ME}: Error $1. Exit Code $2 ${txtrst}"
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
    # remove old cache files
    rm -f .built_dirs
    if [ -f .built_dirs ]; then
        rm .built_dirs
    fi
    if [ -f "bad_jobs.txt" ]; then
        ./scripts/list_bad_job.sh -d
    fi
    if [ -f repo_links.txt.enc ]; then
        rm repo_links.txt.enc
    fi
fi

if [[ "$HOSTLESS" != "yes" ]]; then
    vecho "Getting host's repo_links..." 1
    wget -q "https://oceanai.mit.edu/monte/clients/repo_links.txt.enc"
    EXIT_CODE=$?
    wait
    if [[ $EXIT_CODE -ne 0 ]]; then
        echo "$txtylw      wget failed with code $EXIT_CODE. Continuing with local repo_links.txt ...$txtrst"
    else
        ./scripts/encrypt_file.sh repo_links.txt.enc >/dev/null
        EXIT_CODE=$?
        if [[ "$EXIT_CODE" -ne 0 ]]; then
            vexit "encrypt_file.sh failed do decrypt file repo_links.txt.enc with code $EXIT_CODE" 4
        fi
    fi
fi

echo $(tput bold)"-------------------------------------------------------" $txtrst

#-------------------------------------------------------
#  Part 2: Get the host's job queue files and decrypts them
#-------------------------------------------------------
if [ -f host_job_queue.txt.enc ]; then
    rm host_job_queue.txt.enc
fi

if [ "$HOSTLESS" = "no" ]; then
    vecho "Getting host's job queue..." 1
    wget -q "https://oceanai.mit.edu/monte/clients/host_job_queue.txt.enc"
    EXIT_CODE=$?
    wait
    if [[ "$EXIT_CODE" -ne 0 ]]; then
        echo "$txtylw      wget failed with code $EXIT_CODE. Continuing with local repo_links.txt ...$txtrst"
    elif [[ ! -f "host_job_queue.txt.enc" ]]; then
        echo "$txtylw      file host_job_queue.txt.enc not found, but wget had no error? Continuing with local repo_links.txt ...$txtrst"
    else
        ./scripts/encrypt_file.sh host_job_queue.txt.enc >/dev/null
        EXIT_CODE=$?
        if [[ "$EXIT_CODE" -ne 0 ]]; then
            vexit "encrypt_file.sh failed do decrypt file host_job_queue.txt.enc with code $EXIT_CODE" 5
        fi
    fi
else
    if [ ! -f "host_job_queue.txt" ]; then
        vexit "could not find host_job_queue.txt" 6
    fi
fi

#-------------------------------------------------------
#  Part 3: Determine which job to run
#-------------------------------------------------------
# add newline if not present at end of file
[ "$(tail -c1 "$QUEUE_FILE")" ] && echo >>"$QUEUE_FILE"

# get length of queue (number of jobs)
length=$(wc -l "$QUEUE_FILE" | awk '{print $1}')
for ((i = 1; i <= length; i++)); do
    # select ith line from the queue
    line=$(awk -v n=$i 'NR == n {print; exit}' "$QUEUE_FILE")
    if [[ -z $line ]]; then
        vecho "Line was empty. Continuing..." 5
        continue
    fi

    # Skips over commented out lines (start with #)
    if [[ $line == \#* ]]; then
        vecho "Skipping comment..." 5
        continue
    fi

    # check number of runs left for that job
    linearray=($line)
    JOB_FILE=${linearray[0]}
    RUNS_DES=${linearray[1]}
    RUNS_ACT=${linearray[2]}
    RUNS_LEFT=$((RUNS_DES - RUNS_ACT))

    # filters out known bad jobs
    if [ -f "bad_jobs.txt" ]; then
        # Checks if the JOB_FILE is in bad_jobs.txt
        if grep -Fxq "$JOB_FILE" "bad_jobs.txt"; then
            ALL_JOBS_OK="no"
            vecho "Skipping bad job $JOB_FILE ..." 1
            JOB_FILE=""
            continue
        fi
    fi

    # checks if it has runs left
    if [[ $RUNS_LEFT -gt 0 ]]; then

        # check that it is in a directory
        JOB_FILE_NAME=$(basename $JOB_FILE)
        JOB_DIR_FULL=$(dirname ${JOB_FILE})
        JOB_DIR=${JOB_DIR_FULL#*/}
        JOB_NAME=$(echo "$JOB_DIR_FULL" | cut -d '/' -f 1)
        FILE="$JOB_NAME.tar.gz.enc"

        if [ -z "$JOB_NAME" ]; then
            vecho "Job not in a directory. Skipping..." 1
            JOB_FILE=""
            continue
        fi

        GOOD_JOB_FILE=$JOB_FILE
        GOOD_RUNS_DES=$RUNS_DES
        GOOD_RUNS_ACT=$RUNS_ACT
        GOOD_RUNS_LEFT=$RUNS_LEFT
        probability_skip=75
        RANDOM=$(date '+%N')
        random_number=$((RANDOM % 100))
        # Randomly selects this job. Or tries the next one
        if ((random_number > probability_skip)); then
            break # takes the job
        else
            vecho "Randomly skipping job..." 1
        fi
    # No runs left
    else
        JOB_FILE=""
    fi
done

# Un-cacheing the last known usable job
JOB_FILE=$GOOD_JOB_FILE
RUNS_LEFT=$GOOD_RUNS_LEFT
RUNS_ACT=$GOOD_RUNS_ACT
RUNS_DES=$GOOD_RUNS_DES

# Ensures a job has been chosen
if [[ -z $JOB_FILE ]]; then
    vecho "No jobs left to run. Exiting..." 1
    if [ "$ALL_JOBS_OK" == "no" ]; then
        vexit "finished all ok jobs, but some were bad. Fix jobs in bad_jobs.txt and rerun" 1
    fi
    exit 1
fi

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
JOB_NAME=$(echo "$JOB_DIR_FULL" | cut -d '/' -f 1)
FILE="$JOB_NAME.tar.gz.enc"

if [ -f "$FILE" ]; then
    rm "$FILE"
fi

if [ "$HOSTLESS" = "no" ]; then
    vecho "Getting job dirs..." 1
    wget -q "https://oceanai.mit.edu/monte/clients/job_dirs/$FILE"
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        vecho "wget https://oceanai.mit.edu/monte/clients/job_dirs/$FILE failed with code $EXIT_CODE" 1
        # - - - - - - - - - - - - - - - - - - - - -
        # Network error
        if [[ $EXIT_CODE -eq 4 ]]; then
            echo "$txtylw      wget failed with code $EXIT_CODE. Trying to run a local copy...$txtrst"
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
        # Success, move encrypted file to job_dirs, decrypt it
        if [ ! -d "job_dirs" ]; then
            mkdir job_dirs
        fi
        mv "$FILE" job_dirs/
        ./scripts/encrypt_file.sh "job_dirs/$FILE" >/dev/null
        EXIT_CODE=$?
        if [[ $EXIT_CODE -ne 0 ]]; then
            vexit "encrypt_file.sh failed do decrypt file job_dirs/$FILE with code $EXIT_CODE" 7
        fi
    fi
fi

#-------------------------------------------------------
#  Part 5: Run it!
#-------------------------------------------------------

if [ "$HOSTLESS" = "yes" ]; then
    ./client_scripts/run_job.sh --job_file="$JOB_FILE" -nh
else
    ./client_scripts/run_job.sh --job_file="$JOB_FILE"
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

# # update the queue file (helpful if trying to run w/o a host)
# if [[ "$OSTYPE" == "darwin"* ]]; then
#         # macOS
# sed -i '' 's@^$JOB_FILE.*@$JOB_FILE $NUM_RUNS_DES $NUM_RUNS_ACT@' "$QUEUE_FILE"
# else
# # Linux
# sed -i "s@^$JOB_FILE.*@$JOB_FILE $NUM_RUNS_DES $NUM_RUNS_ACT@" "$QUEUE_FILE"
# fi

exit 0
