#!/bin/bash
#--------------------------------------------------------------
#   Script: monte_clean.sh
#   Author: Kevin Becker
#     Date: May 26 2023
#----------------------------------------------------------
#  Part 1: Declare global var defaults
#----------------------------------------------------------

BINARIES="no"
RESULTS="no"
CACHE="no"
MOOS_DIRS="no"
OVERRIDE_CHECKS="no"
METADATA="no"
ALL="no"

ME="monte_clean.sh"
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [SWITCHES]        "
        echo "                                                          "
        echo "  Cleans your carlo_dir directory. "
        echo "      Deletes all old moos-ivp-extend dirs (last used >30 days ago)."
        echo "      Deletes all logs in all moos-ivp-extend dirs. "
        echo "      Deletes any artifacts from monte-moos. "
        echo "                                                          "
        echo "  --help, -h       display this help and exit        "
        echo "  --verbose, v                "
        echo "  --binaries, -b   binaries in each moos-dir            "
        echo "  --cache, -c      Which dirs have been built, which jobs are bad.               "
        echo "  --results        removes all dirs named results               "
        echo "  --moos_dirs      removes all moos-ivp-extend dirs         "
        echo "  --all            enable all options         "
        echo "  -y               bypass any safety checks             "
        echo "  --metadata, -m   status.txt, myname.txt               "
        echo "                   Rarely used."
        exit 0
    elif [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
        VERBOSE=1
    elif [[ "${ARGI}" = "--binaries" || "${ARGI}" = "-b" ]]; then
        BINARIES="yes"
    elif [[ "${ARGI}" = "--cache" || "${ARGI}" = "-c" ]]; then
        CACHE="yes"
    elif [[ "${ARGI}" = "--metadata" || "${ARGI}" = "-m" ]]; then
        METADATA="yes"
    elif [ "${ARGI}" = "--results" ]; then
        # This is a dangerous option, so we make it prompt the user
        RESULTS="yes"
    elif [ "${ARGI}" = "--moos_dirs" ]; then
        MOOS_DIRS="yes"
    elif [ "${ARGI}" = "--all" ]; then
        # This is a dangerous option, so we make it prompt the user
        ALL="yes"
    elif [ "${ARGI}" = "-y" ]; then
        OVERRIDE_CHECKS="yes"
    else
        vexit "Bad Arg:[$ARGI]. Use --help or -h for help." 1
    fi
done

#-------------------------------------------------------
#  Part 3: Safety checks, options
#-------------------------------------------------------

# Check the shell enviornment
monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi

# Require confirmation for dangerous options
if [ $ALL = "yes" ]; then
    if [ $OVERRIDE_CHECKS != "yes" ]; then
        echo "Are you sure you want to clean all?"
        echo "Press any key to continue, or Ctrl-C to cancel."
        read -n 1 -s
        OVERRIDE_CHECKS="yes"
    fi
    if [ "$MYNAME" == "$MONTE_MOOS_HOST" ]; then
        METADATA="yes"
    else
        RESULTS="yes"
        METADATA="yes"
        BINARIES="yes"
        MOOS_DIRS="yes"
    fi
fi
if [ $RESULTS = "yes" ] && [ $OVERRIDE_CHECKS != "yes" ]; then
    echo "Are you sure you want to remove all subdirs in results?"
    echo "Press any key to continue, or Ctrl-C to cancel."
    read -n 1 -s
fi
if [ $METADATA = "yes" ] && [ $OVERRIDE_CHECKS != "yes" ]; then
    echo "Are you sure you want to remove all metadata?"
    echo "Press any key to continue, or Ctrl-C to cancel."
    read -n 1 -s
fi


#-------------------------------------------------------
# Part 4: Handle moos-ivp-extend directories
#-------------------------------------------------------
if [[ "${BINARIES}" = "yes" ]]; then
    vecho "Cleaning binaries..." 1
    [ -f "${CARLO_DIR_LOCATION}/.built_dirs" ] && rm -f "${CARLO_DIR_LOCATION}/.built_dirs"
fi

if [ -d "${MONTE_MOOS_CLIENT_REPOS_DIR}" ]; then
    starting_dir="$(pwd)"
    cd "${MONTE_MOOS_CLIENT_REPOS_DIR}" || vexit "Error with cd into ${MONTE_MOOS_CLIENT_REPOS_DIR}" 1
    
    
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Part 4a: Remove moos-dirs if specified
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    if [[ "${MOOS_DIRS}" = "yes" ]]; then
        vecho "Removing all moos-ivp-extend dirs in $(pwd)" 1
        rm -rf moos-ivp-*
    fi
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Part 4b: Clean other moos-ivp-extend directories
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    if find . -maxdepth 1 -type d -name 'moos-ivp-*' | read -r; then
        for dir in moos-ivp*/; do
            vecho "Cleaning $dir in $pwd..." 1
            cd $dir || vexit "Error with cd into $dir" 1

            #- - - - - - - - - - - - - - - - - - - - - - - - - -
            # Part 4c: Clean binaries (ONLY IF SPECIFIED)
            #- - - - - - - - - - - - - - - - - - - - - - - - - -
            # Clean the binaries
            if [[ "${BINARIES}" = "yes" ]]; then
                vecho "Cleaning binaries in $dir..." 2
                rm -rf build/*
                rm -rf lib/*
                rm -rf bin/p*
                find . -name '.build_log.txt' -exec rm -rf {} \; 2>/dev/null
            fi

            # ALWAYS remove temporary files, alogs, and other junk
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
    else
        vecho "No moos-ivp-extend directories found." 1
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Part 4d: ALWAYS clean moos-ivp/ivp/missions
    #- - - - - - - - - - - - - - - - - - - - - - - - - -
    # Always clean all moos-ivp missions
    if [ -d moos-ivp ]; then
        if [[ -d moos-ivp/trunk/ivp/missions ]]; then
            cd moos-ivp/trunk/ivp/missions || vexit "Error with cd from $(pwd) to moos-ivp/trunk/ivp/missions" 1
        else
            cd moos-ivp/ivp/missions || vexit "Error with cd from $(pwd) to moos-ivp/ivp/missions" 1
        fi
        vecho "Cleaning $pwd with ./clean.sh..." 1
        ./clean.sh >/dev/null
        cd - >/dev/null || vexit "Error with cd -" 1
    fi
    cd "$starting_dir" || vexit "Error with cd $starting_dir" 1
fi

#-------------------------------------------------------
# Part 5: Clean all results folders
#-------------------------------------------------------
if [[ "${RESULTS}" = "yes" ]]; then
    vecho "Cleaning results" 1
    if [ "$MYNAME" == "$MONTE_MOOS_HOST" ]; then
        echo "Host is $MONTE_MOOS_HOST. Not cleaning results."
        : # <-- No-op. Durring dev, it would do: # rm -rf /home/web/monte/results/* >/dev/null
    else
        # Keeps backups of last two deleted results dirs, just in case
        if [ -d .deleted_results_2 ]; then
            rm -rf .deleted_results_2/
        fi
        if [ -d .deleted_results ]; then
            mv .deleted_results .deleted_results_2
        fi
        [[ -d results ]] && {
            mv results .deleted_results
            vecho "Moving old results files to .deleted_results and .deleted_results_2 just in case..." 1
        }
    fi
fi

#-------------------------------------------------------
# Part 6: Clean all metadata (queues, statuses, etc.)
# Mostly unnecessary, since these shouldn't cause harm
#-------------------------------------------------------
if [[ "${METADATA}" = "yes" ]]; then
    vecho "Cleaning metadata (status.txt and myname.txt)" 1
    [ -f "${CARLO_DIR_LOCATION}/status.txt" ] && rm -f "${CARLO_DIR_LOCATION}/status.txt"
    [ -f "${CARLO_DIR_LOCATION}/myname.txt" ] && rm -f "${CARLO_DIR_LOCATION}/myname.txt"
    find "${CARLO_DIR_LOCATION}" -type f -name '*_job_queue.txt' -exec rm {} \; 2>/dev/null
fi

#-------------------------------------------------------
# Part 7: Clean all cache files:
#           - bulit_dirs
#           - bad_jobs
#-------------------------------------------------------
if [[ "${CACHE}" = "yes" ]]; then
    vecho "Cleaning cache (.build_dirs, bad_jobs.txt)" 1
    [ -f "${CARLO_DIR_LOCATION}/.built_dirs" ] && rm -f "${CARLO_DIR_LOCATION}/.built_dirs"
    if [[ $MYNAME != "$MONTE_MOOS_HOST" ]]; then
        /"${MONTE_MOOS_BASE_DIR}"/client_scripts/list_bad_job.sh -d
    fi
    # Remove old temp job dirs
    [[ -d ${CARLO_DIR_LOCATION}/.temp_job_dirs ]] && { rm -rf "${CARLO_DIR_LOCATION}"/.temp_job_dirs; }
fi

#-------------------------------------------------------
# Part 8: ALWAYS do the following
#-------------------------------------------------------
# Always clean all remaining .enc files
vecho "Cleaning all remaining files" 3
find "${CARLO_DIR_LOCATION}" -name '*.enc' -exec rm -rf {} \; 2>/dev/null
find "${CARLO_DIR_LOCATION}" -name '*.enc.*' -exec rm -rf {} \; 2>/dev/null

# Always remove temporary files
rm -f "${CARLO_DIR_LOCATION}"/.old_*_job_queue.txt
rm -f "${CARLO_DIR_LOCATION}"/.temp_queue.txt
rm -f "${CARLO_DIR_LOCATION}"/.tmp_*

# Remove empty results folders
[[ -d ${CARLO_DIR_LOCATION}/results ]] && { find "${CARLO_DIR_LOCATION}"/results -type d -delete 2>/dev/null; }


# Remove old moos-dirs
if [[ $MYNAME != "$MONTE_MOOS_HOST" ]]; then
    vecho "Removing moos_dirs older than 30 days... ${MONTE_MOOS_CLIENT_REPOS_DIR}" 1
    mkdir -p ${MONTE_MOOS_CLIENT_REPOS_DIR}
    find ${MONTE_MOOS_CLIENT_REPOS_DIR} -type d -mtime +30 -exec echo "     Removing: {} since its older than 30 days..." \; -exec rm -r {} \;
fi


exit 0
