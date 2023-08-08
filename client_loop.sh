#!/bin/bash 
# Kevin Becker Jun 9 2023

ME=$(basename "$0")
VERBOSE=0
PERPETUAL=""
RE_UPDATE="yes"
IGNORE_WARNING="no"
HOSTLESS="no"

txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green                     
txtylw=$(tput setaf 3) # Yellow                     
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey                     
txtbld=$(tput bold)    # Bold                         
# vecho "message" level_int
secho() {   ./scripts/secho.sh "$1" ; } # status echo
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }
check_quit() { if [ -f "force_quit" ]; then secho "force_quit file found. Exiting" ; exit 0 ; fi }
check_sleep() { for i in $(seq 1 1 $1 ); do check_quit ; sleep 1 ; done ; }

# Updates once per day
day_of_last_update=$(date +%u) # current day

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [OPTIONS]"
        echo "Options:                                                  " 
        echo " --help, -h Show this help message                        " 
        echo " --hostless, -nh run everything without the host            " 
        echo " -y,        Ignore the warning message                    " 
        echo " -p,        perpetual mode. Does not exit "
        echo "            when there are no more jobs"
        echo "            remaining in the queue     "
        exit 0;
    elif [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
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


#-------------------------------------------------------
#  Part 1b: Warn the user about loosing files
if [ -d "job_dirs" ] && [ "$(hostname)" != "oceanai" ]; then
    if [ "$IGNORE_WARNING" != "yes" ]; then
        echo "WARNING: Starting the client loop will delete ALL"
        echo "job files, post_processing_script.sh's and repo_links.txt"
        echo "files in this computer's job_dirs directory."
        echo "Press any key to continue, or Ctrl-C to cancel."
        read -n 1 -s
    fi
fi
#  Part 1c: Check for force_quit file
if [ -f "force_quit" ]; then
    secho "force_quit file found. Not starting up until this is manually deleted."
    exit 0
fi



#-------------------------------------------------------
#  Part 2: Run, and (sometimes) update
#-------------------------------------------------------
while true; do

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Clean from the last run
    ./clean.sh

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Run the next job, updating if necessary
    FLAGS=""
    if [ "$RE_UPDATE" = "yes" ]; then
        RE_UPDATE=""
        day_of_last_update=$(date +%u)
    else
        FLAGS+=" --noup"
    fi
    if [ "$HOSTLESS" = "yes" ]; then
        FLAGS+=" --hostless"
    fi
    ./client_scripts/run_next.sh $FLAGS
    EXIT=$?


    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 1: Queue is empty
    if [ $EXIT -eq 1 ]; then
        echo "$0: No more jobs to run"
        if [ -z "$PERPETUAL" ]; then
            secho "No more jobs to run, and not in perpetual mode. Exiting..."
            ./clean.sh
            exit 0
        fi
        secho "Perpetual mode: waiting 30 seconds before checking again..."
        check_sleep 30
        RE_UPDATE="yes"
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 2: Job was bad
    elif [ $EXIT -eq 2 ]; then
        secho "$0 skipping bad job..."
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code 130: ctrl-c
    elif [ $EXIT -eq 130 ]; then
        vexit "Recieved ctrl-c, exiting..." 130
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Exit code !=0: run next failed for unknown reason
    elif [ $EXIT -ne 0 ]; then
        vexit "./client_scripts/run_next.sh failed with code $EXIT_CODE" 2
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
