#!/bin/bash
# Kevin Becker Jun 9 2023

ME=$(basename "$0")
VERBOSE=0
TEST=""
HOSTLESS="no"
OLD_PATH=$PATH
OLD_DIRS=$IVP_BEHAVIOR_DIRS
txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
secho() { ./scripts/secho.sh "$1"; } # status echo
vexit() {
    secho $txtred"$ME: Error $1. Exit Code $2" $txtrst
    safe_exit "$2"
}
safe_exit() {
    PATH=$OLD_PATH
    IVP_BEHAVIOR_DIRS=$OLD_IVP_BEHAVIOR_DIRS
    export PATH
    export IVP_BEHAVIOR_DIRS
    if [ $1 -ne 0 ]; then
        echo ""
        echo "${txtred}$ME Exiting safely. Resetting PATH and IVP_BEHAVIOR_DIRS... ${txtrst}"
    fi
    exit $1
}
trap ctrl_c INT
ctrl_c() {
    safe_exit 130
}

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------

for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --job_file=[JOB_FILE]       "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --job_file=[FILE]    job file to be run"
        echo "               If not specified, the first flag-less argument   "
        echo "               is assumed to be the JOB_FILE, and the script   "
        echo "               is automatically put into test mode.   "
        echo " --test, -t   used to test your job's post_process_results  "
        echo "              script. Sets verbosity to 1 (if not already  "
        echo "              set) and skips the extract_results.sh script."
        echo "              Test mode is enabled when the --job_file= flag"
        echo "              is not explicitly specified. Skips the "
        echo "              extract_results.sh script."
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo " --hostless, -nh run everything without the host              "
        echo "    Set verbosity                                     "
        safe_exit 0
    elif [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" = "--test" || "${ARGI}" = "-t" ]]; then
        TEST="yes"
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="yes"
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        # Job file provided without the flag
        # Assumed running as test
        if [ -z $JOB_FILE ]; then
            TEST="yes"
            JOB_FILE=$ARGI
        else
            vexit "Bad Arg: $ARGI " 1
        fi
    fi
done

# Removes something from a path-like variable
remove_from_var() {
    INDEX=1
    output_var=""
    while [ 1 ]; do
        PART=$(echo $1 | cut -d : -f $INDEX)
        if [[ "${PART}" = "" ]]; then
            break
        elif [[ "${PART}" =~ "$2" ]]; then
            INDEX=$((INDEX + 1))
            continue
        else
            output_var+="$PART:"
        fi
        INDEX=$((INDEX + 1))
    done
    output_var="${output_var%:}"
    echo "$output_var"
}

#-------------------------------------------------------
#  Part 1b: Set up test mode
#-------------------------------------------------------
if [ "$TEST" = "yes" ]; then
    if [ $VERBOSE -eq 0 ]; then
        VERBOSE=1
    fi
    vecho "Running in test mode" 0
    vecho "Cleaning old alog files with ./clean.sh" 0
    ./clean.sh # cleans old alogs
    OFFLOAD="no"
fi

#-------------------------------------------------------
#  Part 1c: Clear extraneous paths and dirs
#-------------------------------------------------------
OLD_PATH=$PATH
OLD_DIRS=$IVP_BEHAVIOR_DIRS
# removes all paths containing moos-ivp- as part of the path
vecho "Temporarially removing moos-ivp-* from PATH and IVP_BEHAVIOR_DIRS" 1
PATH=$(remove_from_var "$PATH" "moos-ivp-")
IVP_BEHAVIOR_DIRS=$(remove_from_var "$IVP_BEHAVIOR_DIRS" "moos-ivp-")
export PATH
export IVP_BEHAVIOR_DIRS

#-------------------------------------------------------
#  Part 2: Check that command-line arguments are valid
#-------------------------------------------------------
if [ -z "$JOB_FILE" ]; then
    vexit "Job file must be set" 2
fi
# adds job_gropus to the directory if neded (should be needed!)
if [ ! -f "$JOB_FILE" ]; then
    JOB_FILE="job_dirs/$JOB_FILE"
    if [ ! -f "$JOB_FILE" ]; then
        vexit "Job file must exist at $JOB_FILE" 2
    fi
fi

#-------------------------------------------------------
#  Part 3: Run each component and check exit codes
#          Updates status file along the way
#-------------------------------------------------------

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3a: Check job file
echo -n "[1] Checking job file..."
if [ "$HOSTLESS" = "yes" ] || [ "$TEST" = "yes" ]; then
    vecho "./check_job.sh  --job_file=$JOB_FILE" 1
    ./check_job.sh --job_file=$JOB_FILE
else
    vecho "./check_job.sh  --job_file=$JOB_FILE --client" 1
    ./check_job.sh --job_file=$JOB_FILE --client
fi
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    vexit "Job file is invalid (failed check_job.sh with exit code $EXIT_CODE)" 3
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3b: Update the moos directories
echo "[2] Updating dirs from job file... "
secho "Updating_dirs from $JOB_FILE"
vecho "./client_scripts/update_dirs.sh --job_file=$JOB_FILE -j2" 1
./client_scripts/update_dirs.sh --job_file=$JOB_FILE -j2
if [ $? -ne 0 ]; then
    vexit "updating dirs mentioned in job using: ./client_scripts/update_dirs.sh --job_file=$JOB_FILE -j2" 3
fi
echo $txtgrn"      Done updating dirs" $txtrst

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3c: Run the job file
vecho "./client_scripts/xlaunch_job.sh --job_file=$JOB_FILE -v=$VERBOSE" 1
echo "[3] Running job from file..."
secho "Running job $JOB_FILE"
./client_scripts/xlaunch_job.sh --job_file=$JOB_FILE -v=$VERBOSE
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 2 ]]; then
    echo "Mission timed out. Extracting results anyway..."
else
    if [ $EXIT_CODE -ne 0 ]; then
        vexit "./client_scripts/xlaunch_job.sh --job_file=$JOB_FILE exited with exit code: $EXIT_CODE" 5
    fi
fi
echo $txtgrn"      finished running job" $txtrst

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3d: Exit test mode, tell user to run extract_results.sh
if [ "$TEST" = "yes" ]; then
    echo ""
    echo "---------------------- TEST MODE ----------------------"
    echo "Skipping post-processing and sending results script."
    echo "Test your post-processing script using the following command: "
    echo $(tput smul)${txtblu}"./client_scripts/extract_results.sh $JOB_FILE"$txtrst
    # echo "$(tput bold)Be sure to run $(tput smul)${txtblu}clean.sh${txtrst} $(tput bold)before trying to run again!"
    safe_exit 0
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3e: Post-process, send the results
secho "Extracting results_from $JOB_FILE"
if [ "$HOSTLESS" = "yes" ]; then
    vecho "./client_scripts/extract_results.sh -no --job_file=$JOB_FILE" 1
    ./client_scripts/extract_results.sh -no --job_file=$JOB_FILE
else
    vecho "./client_scripts/extract_results.sh --job_file=$JOB_FILE" 1
    ./client_scripts/extract_results.sh --job_file=$JOB_FILE
fi
if [ $? -ne 0 ]; then
    vexit "error extracting the results. Recieved exit code $? with ./client_scripts/extract_results.sh -v=$VERBOSE --job_file=$JOB_FILE" 6
fi

echo $txtgrn"      Results extracted" $txtrst
safe_exit 0
