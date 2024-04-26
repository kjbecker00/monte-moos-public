#!/bin/bash
# Kevin Becker Nov 17 2023
ME="select_job.sh"
probability_skip=75 # proability it skips the first available job
QUEUE_FILE=""
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [options]         "
        echo "                                                          "
        echo " Selects a job from the given queue file, echos that line."
        echo " Since this script's output is an echo, you MUST keep the "
        echo " \"vecho\" variable at zero unless you're debugging.      "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --queue_file=, -q= run give the queue file to use. This  "
        echo "                    file must exist on the local machine."
        exit 0
    elif [[ "${ARGI}" == "--queue_file="* || "${ARGI}" == "-q="* ]]; then
        QUEUE_FILE="${ARGI#*=}"
    else
        vexit "Bad Arg: $ARGI " 3
    fi
done

if [[ ! -f "$QUEUE_FILE" ]]; then
    vexit "Queue file does not exist: $QUEUE_FILE" 3
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
    # linearray=($line)
    read -ra linearray <<<"$line"
    JOB_FILE=${linearray[0]}
    JOB_ARGS=""
    RUNS_DES=""
    RUNS_ACT=""

    for j in "${linearray[@]}"; do
        if [[ "$j" == "$JOB_FILE" ]]; then
            continue
        elif [[ "$j" == "--"* ]]; then
            if [[ ! $JOB_ARGS == "" ]]; then
                JOB_ARGS="${JOB_ARGS} ${j}"
            else
                JOB_ARGS="${j}"
            fi
        elif [[ $RUNS_DES -eq "" ]]; then
            RUNS_DES=$j
        else
            RUNS_ACT=$j
        fi
    done

    RUNS_LEFT=$((RUNS_DES - RUNS_ACT))

    if is_bad_job "$JOB_FILE $JOB_ARGS"; then
        vecho "Skipping bad job $JOB_FILE $JOB_ARGS ..." 1
        continue
    # checks if it has runs left
    elif [[ $RUNS_LEFT -gt 0 ]]; then
        vecho "job $JOB_FILE $JOB_ARGS is not bad" 1
        GOOD_JOB_FILE=$JOB_FILE
        GOOD_JOB_ARGS=$JOB_ARGS
        GOOD_RUNS_DES=$RUNS_DES
        GOOD_RUNS_ACT=$RUNS_ACT
        random_number=$((RANDOM % 100))
        # Randomly selects this job. Or tries the next one
        if ((random_number > probability_skip)); then
            vecho "Taking this job..." 1
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
JOB_ARGS=$GOOD_JOB_ARGS
RUNS_ACT=$GOOD_RUNS_ACT
RUNS_DES=$GOOD_RUNS_DES

vecho "Job $JOB_FILE $JOB_ARGS selected" 3

# Ensures a job has been chosen
if [[ -z $JOB_FILE || $JOB_FILE == "" ]]; then
    vecho "No jobs left to run. Exiting..." 1
    if [ "$ALL_JOBS_OK" == "no" ]; then
        vexit "Finished all ok jobs, but some were bad. Fix jobs in bad_jobs.txt and rerun" 2
    fi
    exit 1
fi

if [[ "$JOB_ARGS" == "" ]]; then
    echo "$JOB_FILE $RUNS_DES $RUNS_ACT"
else
    echo "$JOB_FILE $JOB_ARGS $RUNS_DES $RUNS_ACT"
fi
exit 0
