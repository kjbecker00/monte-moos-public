#!/bin/bash
# Kevin Becker Jun 9 2023

ME="monte_client_loop.sh"
PERPETUAL=""
IGNORE_WARNING="no"
HOSTLESS=""

# shellcheck disable=SC1090
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"

# Updates once per hour
last_update_time=$(get_hour)
last_update_time=$((last_update_time-1)) # forces an update on the first iteration
#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
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
        echo "  --verbose=num, -v=num or --verbose, -v              "
        exit 0
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="--hostless"
    elif [[ "${ARGI}" = "-p" ]]; then
        PERPETUAL="yes"
    elif [[ "${ARGI}" = "-y" ]]; then
        IGNORE_WARNING="yes"
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        vexit "Unrecognized option: $ARGI" 1
    fi
done

#-------------------------------------------------------
#  Part 1: Set enviornment, checks
#-------------------------------------------------------
# a: Check for monte_info file. Useful if you have
#    multiple carlo_dirs for different hosts
#-------------------------------------------------------
if [[ -f monte_info ]]; then
    echo "Found a monte_info file. Using it to set variables."
    # shellcheck disable=SC1091
    source monte_info
fi

monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi

#-------------------------------------------------------
#  Part 2: Warnings
#-------------------------------------------------------
if [ -d ".temp_job_dirs" ] && [ "$MYNAME" != "$MONTE_MOOS_HOST" ]; then
    if [ "$IGNORE_WARNING" != "yes" ]; then
        echo "WARNING: The .temp_job_dirs directory may be overwritten. "
        echo "Be sure to commit & push changes in this carlo_dir directory."
        echo "Press any key to continue, or Ctrl-C to cancel."
        read -n 1 -s
    fi
fi

if [ "$MYNAME" = "$MONTE_MOOS_HOST" ]; then
    vexit "This script should only be run on a client" 1
fi

#-------------------------------------------------------
#  Part 3: Check for force_quit file
#-------------------------------------------------------
if [ -f "${CARLO_DIR_LOCATION}/force_quit" ]; then
    secho "${CARLO_DIR_LOCATION}/force_quit file found. Not starting up until this is manually deleted."
    exit 0
fi

#-------------------------------------------------------
#  Part 4: Force updates on monte-moos and moos-dirs
#-------------------------------------------------------
monte_clean.sh --cache

#-------------------------------------------------------
#  Part 5: Set temporary .temp_job_dirs
#-------------------------------------------------------
if [ "$HOSTLESS" = "--hostless" ]; then
    # If the runtime .temp_job_dirs directory doesn't exist, copy the local_job_dirs
    vecho "Hostless..." 10
    if [ -d "${CARLO_DIR_LOCATION}/local_job_dirs" ]; then
        vecho "Copying local_job_dirs to .temp_job_dirs..." 3
        cp -rp "${CARLO_DIR_LOCATION}/local_job_dirs" "${CARLO_DIR_LOCATION}/.temp_job_dirs"
    fi
else
    rm -rf "${CARLO_DIR_LOCATION}/"*_job_queue.txt
fi

#-------------------------------------------------------
#  Part 6: Run, and (sometimes) update!
#-------------------------------------------------------
while true; do
    vecho "New iteration of loop..." 10
    monte_clean.sh
    this_hour=$(get_hour)

    # Variable sleep time (1 minute during the day, 5 minutes overnight)
    if [[ $this_hour -gt 8 && $this_hour -lt 18 ]]; then
        SLEEP_TIME=60 # 1 minute during the day
    else
        SLEEP_TIME=300 # 5 minutes overnight
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Determine if a reupdate is needed
    if [[ $PERPETUAL = "yes" ]]; then
        vecho "Perpetual mode. Checking for updates..." 10

        # Populate the reupdate flag
        if [ "$last_update_time" -ne "$this_hour" ]; then
            vecho "Setting re-update flag..." 1
            last_update_time="$this_hour"
            UPDATE_THIS_ITER="--update"

            # Update monte-moos as well
            vecho "${txtgry}Updating monte-moos ${txtrst}" 1
            secho "${txtgry}Updating monte-moos ${txtrst}"
            cd /"${MONTE_MOOS_BASE_DIR}" || vexit "cd /${MONTE_MOOS_BASE_DIR} failed" 1
            git pull 2>&1 >/dev/null || {
                git reset --hard HEAD 2>&1 >/dev/null
                git pull 2>&1 >/dev/null
            }
            cd - >/dev/null
        fi
        

    fi

    # Run the next job and check exit codes
    /"${MONTE_MOOS_BASE_DIR}"/client_scripts/run_next.sh $HOSTLESS $UPDATE_THIS_ITER
    EXIT=$?
    UPDATE_THIS_ITER=""

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
        secho "Skipping bad job..."
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 8: Unable to pull queue file. Trying again
    elif [ $EXIT -eq 8 ]; then
        secho "Unable to pull queue file. Trying again in $SLEEP_TIME seconds..."
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 130: ctrl-c
    elif [ $EXIT -eq 130 ]; then
        vexit "Recieved ctrl-c, exiting..." 130
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code !=0: run next failed for unknown reason
    elif [ $EXIT -ne 0 ]; then
        vexit "/${MONTE_MOOS_BASE_DIR}/client_scripts/run_next.sh $HOSTLESS $UPDATE_THIS_ITER failed with code $EXIT" 2
    fi
    echo ""

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Another way to exit
    check_quit

done

exit 0
