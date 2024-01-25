#!/bin/bash
# Kevin Becker Jun 9 2023

ME="monte_client_loop.sh"
PERPETUAL=""
RE_UPDATE="yes"
IGNORE_WARNING="no"
HOSTLESS="no"
SLEEP_TIME=60

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

# Updates once per day
day_of_last_update=$(date +%u) # current day

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [OPTIONS]"
        echo "                                                          "
        echo " This is a script used to run jobs from the queue. It can "
        echo " run jobs from a local queue file or the host queue file. "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --hostless, -nh run everything without the host            "
        echo " -y,        Ignore the warning message about cleaning results"
        echo " -p,        perpetual mode. Does not exit when there are  "
        echo "            no more jobs left in the queue. Useful for "
        echo "            running in a cluster.     "
        exit 0
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="yes"
    elif [[ "${ARGI}" = "-p" ]]; then
        PERPETUAL="yes"
    elif [[ "${ARGI}" = "-y" ]]; then
        IGNORE_WARNING="yes"
    else
        vexit "Unrecognized option: $ARGI" 1
    fi
done

# Check the shell enviornment
monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 1b: Warn the user about loosing files
#- - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -d "job_dirs" ] && [ "$MYNAME" != "$MONTE_MOOS_HOST" ]; then
    if [ "$IGNORE_WARNING" != "yes" ]; then
        echo "WARNING: All results files. If you are pulling from the host,"
        echo "any new job files may be overwritten with the host's. Be sure "
        echo "to commit & push changes in this carlo_dir directory."
        echo "Press any key to continue, or Ctrl-C to cancel."
        read -n 1 -s
    fi
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 1c: Check if this is the host
#- - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$MYNAME" = "$MONTE_MOOS_HOST" ]; then
    vexit "This script should only be run on a client" 1
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 1d: Check for force_quit file
#- - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "${CARLO_DIR_LOCATION}/force_quit" ]; then
    secho "${CARLO_DIR_LOCATION}/force_quit file found. Not starting up until this is manually deleted."
    exit 0
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - -
# Part 1e: Set the flags for run_next.sh
#- - - - - - - - - - - - - - - - - - - - - - - - - -
FLAGS=""
if [ "$RE_UPDATE" = "yes" ]; then
    RE_UPDATE=""
    day_of_last_update=$(date +%u)
    FLAGS+=" --update"
fi
if [ "$HOSTLESS" = "yes" ]; then
    FLAGS+=" --hostless"

    # If the runtime job_dirs directory doesn't exist, copy the local_job_dirs
    if [ ! -d "${CARLO_DIR_LOCATION}/job_dirs" ]; then
        if [ -d "${CARLO_DIR_LOCATION}/local_job_dirs" ]; then
            cp -rp "${CARLO_DIR_LOCATION}/local_job_dirs" "${CARLO_DIR_LOCATION}/job_dirs"
        fi
    fi
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - -
# Part 1f: Clean cache (bad_jobs.txt, .built_dirs)
#- - - - - - - - - - - - - - - - - - - - - - - - - -
monte_clean.sh --cache

#-------------------------------------------------------
#  Part 2: Run, and (sometimes) update
#-------------------------------------------------------
while true; do

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Clean from the last run
    monte_clean.sh

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Run the next job, updating if necessary
    /${MONTE_MOOS_BASE_DIR}/client_scripts/run_next.sh $FLAGS
    EXIT=$?

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 1: Queue is empty
    if [ $EXIT -eq 1 ]; then
        if [ -z "$PERPETUAL" ]; then
            secho "No more jobs to run, and not in perpetual mode. Exiting..."
            monte_clean.sh
            exit 0
        fi
        secho "Perpetual mode: waiting $SLEEP_TIME seconds before checking again..."
        check_sleep $SLEEP_TIME
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 2: Job was bad
    elif [ $EXIT -eq 2 ]; then
        echo "Skipping bad job..."
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 8: Unable to pull queue file. Trying again
    elif [ $EXIT -eq 8 ]; then
        echo "Unable to pull queue file. Trying again in $SLEEP_TIME seconds..."
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 130: ctrl-c
    elif [ $EXIT -eq 130 ]; then
        vexit "Recieved ctrl-c, exiting..." 130
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code !=0: run next failed for unknown reason
    elif [ $EXIT -ne 0 ]; then
        vexit "/${MONTE_MOOS_BASE_DIR}/client_scripts/run_next.sh $FLAGS failed with code $EXIT" 2
    fi
    echo ""

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Determine if the client should update
    if [ $day_of_last_update -ne $(date +%u) ]; then
        RE_UPDATE="yes"
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Another way to exit
    check_quit

done

exit 0
