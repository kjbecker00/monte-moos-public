#!/bin/bash
# Kevin Becker, June 9 2023

# This script is used to update the queue of jobs to run

ME="monte_host_loop.sh"
LOOP_TIME=60
PERPETUAL="no"
QUEUE_COMPLETE="no"

source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  "
        echo "                                                          "
        echo " This is a script used to start the host-side loop "
        echo "    The host updates the encrypted job files, the queue,"
        echo "    and repo links.  It is recommended to run this script"
        echo "    with tmux. To detach, press ctrl-b then d. To reattach,"
        echo "    execute 'tmux attach' in the terminal."
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --verbose, -v Change verbosity level                        "
        echo " --perpetual, -p Run perpetually (until force_quit file is made)"
        exit 0
    elif [ "${ARGI}" = "--verbose" -o "${ARGI}" = "-v" ]; then
        VERBOSE=1
    elif [ "${ARGI}" = "--perpetual" -o "${ARGI}" = "-p" ]; then
        PERPETUAL="yes"
    else
        vexit "Unrecognized option: $ARGI" 1
    fi
done

#-------------------------------------------------------
#  Part 2: Error handling
#-------------------------------------------------------
# Check the shell enviornment
monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi
# Basic error handling
if [ "$MYNAME" != "$MONTE_MOOS_HOST" ]; then
    vexit "This script should only be run on the host" 1
fi
if [ -f "${CARLO_DIR_LOCATION}/force_quit" ]; then
    secho "${CARLO_DIR_LOCATION}/force_quit file found. Not starting up until this is manually deleted."
    exit 0
fi

#-------------------------------------------------------
#  Part 2b: Clean up any old monte processes
#-------------------------------------------------------
cd "${CARLO_DIR_LOCATION}"
monte_clean.sh --cache
cd - >/dev/null

#-------------------------------------------------------
#  Part 3: Looping thru the queue
#-------------------------------------------------------
while [ "$QUEUE_COMPLETE" != "yes" ] || [ "$PERPETUAL" = "yes" ]; do

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3a: Push latest queue to web
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    secho "Updating queue"
    ${MONTE_MOOS_BASE_DIR}/host_scripts/update_queue.sh
    EXIT_CODE=$?
    vecho " update_queue exit code $EXIT_CODE" 1
    if [ ! $EXIT_CODE -eq 0 ]; then
        if [ $EXIT_CODE -eq 1 ]; then
            vecho "Queue is not complete" 1
            QUEUE_COMPLETE="no"
        else
            vexit "running ${MONTE_MOOS_BASE_DIR}/host_scripts/update_queue.sh returned exit code: $EXIT_CODE" 1
        fi
    else
        QUEUE_COMPLETE="yes"
    fi
    check_quit

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3b: Update the .temp_job_dirs and repo links on the web
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    secho "Updating job dirs"
    ${MONTE_MOOS_BASE_DIR}/host_scripts/update_job_dirs.sh
    EXIT_CODE=$?
    [ $EXIT_CODE -eq 0 ] || { vexit "running ${MONTE_MOOS_BASE_DIR}/host_scripts/update_job_dirs.sh returned exit code: $EXIT_CODE" 2; }
    check_quit

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3c: If it will do another loop, wait a bit
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if [ "$QUEUE_COMPLETE" != "yes" ] || [ "$PERPETUAL" = "yes" ]; then
        echo "Sleeping (as of $(date))" >${CARLO_DIR_LOCATION}/status.txt # can't seco because -n
        echo -n "${txtltblu}Sleeping${txtrst}"
        check_sleep 1
        echo -n "${txtltblu}.${txtrst}"
        check_sleep 1
        echo -n "${txtltblu}.${txtrst}"
        check_sleep 1
        echo "${txtltblu}.${txtrst}"
        check_sleep $LOOP_TIME
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # An easy way to exit without knowing the PID
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    check_quit

    # Clean up any old alogs, artifacts, etc
    monte_clean.sh

done

secho "${txtgrn}Queue is empty, waiting 1 minute for last jobs to come in before exiting${txtrst}"
check_sleep 60
secho "Updating queue one last time (for accurate count and publish all results)"
${MONTE_MOOS_BASE_DIR}/host_scripts/update_queue.sh
secho "${txtgrn}Done${txtrst}"

exit 0
