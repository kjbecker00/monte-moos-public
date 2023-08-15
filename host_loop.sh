#!/bin/bash
# Kevin Becker, June 9 2023

# This script is used to update the queue of jobs to run

ME=$(basename "$0")
VERBOSE=0
PERPETUAL="no"
QUEUE_COMPLETE="no"
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light blue
txtgry=$(tput setaf 8)    # Grey

# Status echo
secho() {
    echo "$1"
    echo "$1 (as of $(date)). To quit, make the file 'force_quit' in this directory" >status.txt
}
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then secho $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() {
    secho $txtred"$ME: Error $1. Exit Code $2" $txtrst
    exit "$2"
}
check_quit() { if [ -f "force_quit" ]; then
    secho "force_quit file found. Exiting"
    exit 0
fi; }
check_sleep() { for i in $(seq 1 1 $1); do
    check_quit
    sleep 1
done; }

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  "
        echo " This is a script used to start the host-side loop "
        echo "    The host updates the encrypted job files, the queue,"
        echo "    and repo links.  It is recommended to run this script"
        echo "    with tmux. To detach, press ctrl-b then d. To reattach,"
        echo "    run 'tmux attach' in this directory."
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
if [ "$(hostname)" != "oceanai" ]; then
    vexit "This script should only be run on oceanai" 1
fi
if [ -f "force_quit" ]; then
    secho "force_quit file found. Not starting up until this is manually deleted."
    exit 0
fi

#-------------------------------------------------------
#  Part 3: Looping thru the queue
#-------------------------------------------------------
while [ "$QUEUE_COMPLETE" != "yes" ] || [ "$PERPETUAL" = "yes" ]; do

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3a: Push latest queue to web
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    secho "Updating queue"
    ./host_scripts/update_queue.sh
    EXIT_CODE=$?
    vecho " update_queue exit code $EXIT_CODE" 1
    if [ ! $EXIT_CODE -eq 0 ]; then
        if [ $EXIT_CODE -eq 1 ]; then
            vecho "Queue is not complete" 1
            QUEUE_COMPLETE="no"
        else
            vexit "running ./host_scripts/update_queue.sh returned exit code: $EXIT_CODE" 1
        fi
    else
        QUEUE_COMPLETE="yes"
    fi
    check_quit

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3b: Update the job_dirs and repo links on the web
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    secho "Updating job dirs"
    ./host_scripts/update_job_dirs.sh
    EXIT_CODE=$?
    [ $EXIT_CODE -eq 0 ] || { vexit "running ./host_scripts/update_job_dirs.sh returned exit code: $EXIT_CODE" 2; }
    check_quit

    secho "Updating repo links"
    ./host_scripts/update_repo_links.sh
    EXIT_CODE=$?
    [ $EXIT_CODE -eq 0 ] || { vexit "running ./host_scripts/update_repo_links.sh returned exit code: $EXIT_CODE" 2; }
    check_quit

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 3c: If it will do another loop, wait a bit
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if [ "$QUEUE_COMPLETE" != "yes" ] || [ "$PERPETUAL" = "yes" ]; then
        echo "Sleeping (as of $(date))" >status.txt # can't seco because -n
        echo -n "${txtltblu}Sleeping${txtrst}"
        check_sleep 60
        echo -n "${txtltblu}.${txtrst}"
        check_sleep 60
        echo -n "${txtltblu}.${txtrst}"
        check_sleep 60
        echo "${txtltblu}.${txtrst}"
        check_sleep 60
        check_sleep 60
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # An easy way to exit without knowing the PID
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    check_quit

done

secho "${txtgrn}Queue is empty, waiting 1 minute for last jobs to come in before exiting${txtrst}"
check_sleep 60
secho "Updating queue one last time (for accurate count and publish all results)"
./host_scripts/update_queue.sh
secho "${txtgrn}Done${txtrst}"
