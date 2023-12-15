#!/bin/bash
#--------------------------------------------------------------
#   Script: clean.sh
#   Author: Kevin Becker, adapted from clean.sh by Michael Benjamin
#     Date: May 26 2023
#----------------------------------------------------------
#  Part 1: Declare global var defaults
#----------------------------------------------------------

BINARIES="no"
RESULTS="no"
MOOS_DIRS="no"
OVERRIDE_CHECKS="no"
METADATA="no"
JOB_DIRS="no"
ALL="no"

ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() {
    echo $txtred"$ME: Error $1. Exit Code $2" $txtrst
    exit "$2"
}

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [SWITCHES]        "
        echo "  --verbose, v                "
        echo "  --binaries, -b   binaries in each moos-dir            "
        echo "  --metadata, -m   statuses, queues, temp files               "
        echo "  --results        removes all dirs named results               "
        echo "  --moos_dirs      removes all moos-ivp-extend dirs         "
        echo "  --all            enable all options         "
        echo "  -y               bypass any safety checks             "
        echo "  --help, -h       display this help and exit        "
        exit 0
    elif [ "${ARGI}" = "--verbose" -o "${ARGI}" = "-v" ]; then
        VERBOSE=1
    elif [ "${ARGI}" = "--metadata" -o "${ARGI}" = "-m" ]; then
        METADATA="yes"
    elif [ "${ARGI}" = "--binaries" -o "${ARGI}" = "-b" ]; then
        BINARIES="yes"
    elif [ "${ARGI}" = "--results" ]; then
        # This is a dangerous option, so we make it prompt the user
        RESULTS="yes"
    elif [ "${ARGI}" = "--job_dirs" ]; then
        JOB_DIRS="yes"
    elif [ "${ARGI}" = "--all" ]; then
        # This is a dangerous option, so we make it prompt the user
        ALL="yes"
    elif [ "${ARGI}" = "-y" ]; then
        OVERRIDE_CHECKS="yes"
    elif [ "${ARGI}" = "--moos_dirs" ]; then
        MOOS_DIRS="yes"
    else
        vexit "Bad Arg:[$ARGI]. Use --help or -h for help." 1
    fi
done

#-------------------------------------------------------
#  Part 3: Safety checks, options
#-------------------------------------------------------
if [ $ALL = "yes" ]; then
    if [ $OVERRIDE_CHECKS != "yes" ]; then
        echo "Are you sure you want to clean all?"
        echo "Press any key to continue, or Ctrl-C to cancel."
        read -n 1 -s
    fi

    if [ "$(hostname)" == "oceanai" ]; then
        METADATA="yes"
    else
        RESULTS="yes"
        METADATA="yes"
        BINARIES="yes"
        JOB_DIRS="yes"
        MOOS_DIRS="yes"
    fi
elif [ $RESULTS = "yes" ] && [ $OVERRIDE_CHECKS != "yes" ]; then
    echo "Are you sure you want to remove all subdirs in results?"
    echo "Press any key to continue, or Ctrl-C to cancel."
    read -n 1 -s
fi

#-------------------------------------------------------
# Part 4: Clean each moos-dir directory
#          binaries, logs, temp files, and other junk
#-------------------------------------------------------
if [ -d moos-dirs ]; then
    cd moos-dirs || vexit "Error with cd" 1
    if find . -maxdepth 1 -type d -name 'moos-ivp-*' | read; then
        # Delete all moos-ivp-extend directories
        if [[ "${MOOS_DIRS}" = "yes" ]]; then
            rm -rf moos-ivp-*
        else
            for dir in moos-ivp-*/; do
                vecho "Cleaning $dir..." 1
                cd $dir || vexit "Error with cd" 1

                # Clean the binaries
                if [[ "${BINARIES}" = "yes" ]]; then
                    rm -rf build/*
                    rm -rf lib/*
                    rm -rf bin/p*
                    find . -name '.build_log.txt' -exec rm -rf {} \; 2>/dev/null
                fi
                # Always remove temporary files, logs, and other junk
                rm -f .DS_Store
                rm -f missions/*/.LastOpenedMOOSLogDirectory
                find . -name '*~' -exec rm -rf {} \; 2>/dev/null
                find . -name '#*' -exec rm -rf {} \; 2>/dev/null
                find . -name '*.moos++' -exec rm -rf {} \; 2>/dev/null
                find . -type f -name '*.dbg' -exec rm {} \; 2>/dev/null
                find . -type f -name '*.moos++' -exec rm {} \; 2>/dev/null
                find . -type f -name '*.DS_Store' -exec rm {} \; 2>/dev/null
                find . -path '*/MOOSLog*' -exec rm -rf {} \; 2>/dev/null
                find . -path '*/LOG_*' -exec rm -rf {} \; 2>/dev/null
                find . -path '*/XLOG_*' -exec rm -rf {} \; 2>/dev/null
                cd - >/dev/null || vexit "Error with cd" 1

            done
        fi
    else
        vecho "No moos-ivp-extend directories found." 1
    fi

    #-------------------------------------------------------
    # Part 5: Always clean moos-ivp/ivp/missions and
    #         .built_dirs
    #-------------------------------------------------------
    # Always clean all moos-ivp missions
    if [ -d moos-ivp ]; then
        cd moos-ivp/ivp/missions || vexit "Error with cd" 1
        ./clean.sh >/dev/null
        cd - >/dev/null || vexit "Error with cd" 1
    fi
    cd .. || vexit "Error with cd" 1
fi

# Always clean all remaining .enc files
find . -name '*.enc' -exec rm -rf {} \; 2>/dev/null
find . -name '*.enc.1' -exec rm -rf {} \; 2>/dev/null
find . -name '*.enc.2' -exec rm -rf {} \; 2>/dev/null

# Always remove temporary files
rm -f .old_*_job_queue.txt
rm -f .temp_queue.txt

# Remove empty results folders
[[ -d results ]] && { find results -type d -delete ; }

#-------------------------------------------------------
# Part 5: Clean all results folders
#-------------------------------------------------------
if [[ "${RESULTS}" = "yes" ]]; then
    if [ "$(hostname)" == "oceanai" ]; then
        : # <-- No-op. Durring dev, it would do: # rm -rf /home/web/monte/results/* >/dev/null
    else
        # Keeps backups of last two deleted results dirs, just in case
        if [ -d .deleted_results_2 ]; then
            rm -rf .deleted_results_2/
        fi
        if [ -d .deleted_results ]; then
            mv .deleted_results .deleted_results_2
        fi
        mv results .deleted_results
    fi
fi

#-------------------------------------------------------
# Part 6: Clean all metadata (queues, statuses, etc.)
#-------------------------------------------------------
# find . -type f -name '.temp_client_job_queue.txt' -exec rm {} \; 2>/dev/null # Don't clean after every mission!
if [[ "${METADATA}" = "yes" ]]; then
    [ -f .built_dirs ] && rm -f .built_dirs
    ./scripts/list_bad_job.sh -d
    [ -f status.txt ] && rm -f status.txt
    [ -f myname.txt ] && rm -f myname.txt

    if [ "$(hostname)" != "oceanai" ]; then
        find . -type f -name 'host_job_queue.txt' -exec rm {} \; 2>/dev/null
        find . -type f -name './repo_links.txt' -exec rm {} \; 2>/dev/null
        ktm >&/dev/null
    fi
fi

#-------------------------------------------------------
# Part 7: Clean all job dirs
#-------------------------------------------------------
if [[ "${JOB_DIRS}" = "yes" ]]; then
    # safety check
    if [ "$(hostname)" != "oceanai" ]; then
        # Keeps backups of last two deleted job dirs, just in case
        if [ -d .deleted_job_dirs_2 ]; then
            rm -rf .deleted_job_dirs_2/
        fi
        if [ -d .deleted_job_dirs ]; then
            mv .deleted_job_dirs .deleted_job_dirs_2
        fi
        mv job_dirs/* .deleted_job_dirs/
    fi

fi

exit 0
