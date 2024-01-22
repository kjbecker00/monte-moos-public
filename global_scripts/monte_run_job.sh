#!/bin/bash
# Kevin Becker Jun 9 2023

ME="monte_run_job.sh"
VERBOSE=0
TEST=""
HOSTLESS="no"
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh
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
        echo "$ME.sh --job_file=[JOB_FILE] [OPTIONS] OR  "
        echo "$ME.sh [JOB_FILE] [OPTIONS] "
        echo "                                                          "
        echo " Runs a job from a job file. "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --job_file=[FILE]    job file to be run"
        echo "               If not specified, the first argument with no   "
        echo "               dashes is assumed to be the JOB_FILE, and the   "
        echo "               script is automatically put into test mode.   "
        echo " --job_args=\"--arg1 --arg2\"   job file arguments "
        echo " --test, -t   used to test your job's post_process_results  "
        echo "              script. Sets verbosity to 1 (if not already  "
        echo "              set) and skips the monte_extract_results.sh script."
        echo "              Test mode is enabled when the --job_file="
        echo "              is not explicitly specified. Skips the "
        echo "              monte_extract_results.sh script."
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo " --hostless, -nh run everything without the host              "
        safe_exit 0
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_args="* ]]; then
        JOB_ARGS="${ARGI#*=}"
    elif [[ "${ARGI}" = "--test" || "${ARGI}" = "-t" ]]; then
        TEST="yes"
    elif [[ "${ARGI}" = "--hostless" || "${ARGI}" = "-nh" ]]; then
        HOSTLESS="yes"
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
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

# Check the shell enviornment
monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi


# Removes something from a path-like variable
remove_from_var() {
    INDEX=0
    output_var=":"
    # Uses ##END_OF_PATH## because sometimes 
    # two ':'s are put next to each other in the path
    INPUT="${1}:##END_OF_PATH##"
    while [ 1 ]; do
        INDEX=$((INDEX + 1))
        PART=$(echo $INPUT | cut -d : -f $INDEX)
        vecho "$PART" 30
        if [[ "${PART}" = "##END_OF_PATH##" ]]; then
            break
        elif [[ "${PART}" = $2 ]]; then
            vecho "   SKIPPING" 30
            continue
        else
            vecho "ADDING..." 30
            output_var+="$PART:"
        fi
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

    if [[ -f clean.sh ]]; then
        vecho "Cleaning old alog files with ./clean.sh" 0
        ./clean.sh # cleans old alogs
        fi
    OFFLOAD="no"
fi


#-------------------------------------------------------
#  Part 1c: Clear extraneous paths and dirs
#-------------------------------------------------------
OLD_PATH=$PATH
OLD_DIRS=$IVP_BEHAVIOR_DIRS
# removes all paths containing moos-ivp- as part of the path
vecho "$ME: Temporarially removing moos-ivp-* from PATH and IVP_BEHAVIOR_DIRS" 1
vecho "$ME: OLD_PATH: $OLD_PATH" 1
PATH=$(remove_from_var "$PATH" "*/moos-ivp-*/bin")
PATH=$(remove_from_var "$PATH" "*/moos-ivp-*/trunk/bin")
PATH=$(remove_from_var "$PATH" "*/moos-ivp-*/scripts")
PATH=$(remove_from_var "$PATH" "*/moos-ivp-*/trunk/scripts")
IVP_BEHAVIOR_DIRS=$(remove_from_var "$IVP_BEHAVIOR_DIRS" "*/moos-ivp-*/lib")
IVP_BEHAVIOR_DIRS=$(remove_from_var "$IVP_BEHAVIOR_DIRS" "*/moos-ivp-*/trunk/lib")
export PATH
export IVP_BEHAVIOR_DIRS
vecho "$ME: PATH after removing all instances of */moos-ivp-*/bin/* and */moos-ivp-*/scripts/*:   $PATH" 1
vecho "$ME: IVP_BEHAVIOR_DIRS: $IVP_BEHAVIOR_DIRS" 1


#-------------------------------------------------------
#  Part 2: Check that command-line arguments are valid
#-------------------------------------------------------
if [ -z "$JOB_FILE" ]; then
    vexit "Job file must be set" 2
fi
# adds job_gropus to the directory if neded (should be needed!)
if [ ! -f "$JOB_FILE" ]; then
    new_JOB_FILE="job_dirs/$JOB_FILE"
    if [ ! -f "$new_JOB_FILE" ]; then
        vexit "Job file must exist at $JOB_FILE" 2
    else
        JOB_FILE=$new_JOB_FILE
    fi
fi

#-------------------------------------------------------
#  Part 3: Run each component and check exit codes
#          Updates status file along the way
#-------------------------------------------------------

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3a: Check job file
echo "[1] Checking job file... "
if [ "$HOSTLESS" = "yes" ] || [ "$TEST" = "yes" ]; then
    echo "$ME running: monte_check_job.sh  --job_file=$JOB_FILE --job_args=\"$JOB_ARGS\""
    monte_check_job.sh --job_file=$JOB_FILE --job_args="$JOB_ARGS"
else
    echo "$ME running: monte_check_job.sh  --job_file=$JOB_FILE --job_args=\"$JOB_ARGS\" --client" 
    monte_check_job.sh --job_file=$JOB_FILE --job_args="$JOB_ARGS" --client
fi
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    vexit "Job file is invalid (failed check_job.sh with exit code $EXIT_CODE)" 3
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3b: Update the moos directories
echo "[2] Updating dirs from job file... "
secho "Updating_dirs from $JOB_FILE"
cd ${CARLO_DIR_LOCATION}
echo "$ME: /${MONTE_MOOS_BASE_DIR}/client_scripts/update_dirs.sh --job_file=$JOB_FILE  --job_args=\"$JOB_ARGS\" -j2" 
cd - > /dev/null
/${MONTE_MOOS_BASE_DIR}/client_scripts/update_dirs.sh --job_file=$JOB_FILE  --job_args="$JOB_ARGS" -j2
if [ $? -ne 0 ]; then
    vexit "updating dirs mentioned in job using: /${MONTE_MOOS_BASE_DIR}/client_scripts/update_dirs.sh --job_file=$JOB_FILE  --job_args=\"$JOB_ARGS\" -j2" 3
fi
echo $txtgrn"      Done updating dirs" $txtrst



#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3c: Run the job file
echo "$ME: /${MONTE_MOOS_BASE_DIR}/client_scripts/xlaunch_job.sh --job_file=$JOB_FILE  --job_args=\"$JOB_ARGS\"  -v=$VERBOSE" 
echo "[3] Running job from file..."
secho "Running job $JOB_FILE $JOB_ARGS"
/${MONTE_MOOS_BASE_DIR}/client_scripts/xlaunch_job.sh --job_file=$JOB_FILE  --job_args="$JOB_ARGS" -v=$VERBOSE
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 2 ]]; then
    echo "Mission timed out. Extracting results anyway..."
else
    if [ $EXIT_CODE -ne 0 ]; then
        vexit "/${MONTE_MOOS_BASE_DIR}/client_scripts/xlaunch_job.sh --job_file=$JOB_FILE  --job_args=\"$JOB_ARGS\" exited with exit code: $EXIT_CODE" 5
    fi
fi
echo $txtgrn"      finished running job" $txtrst

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3d: Exit test mode, tell user to run monte_extract_results.sh
if [ "$TEST" = "yes" ]; then
    echo ""
    echo "---------------------- TEST MODE ----------------------"
    echo "Skipping post-processing and sending results script."
    echo "Test your post-processing script using the following command: "
    echo $(tput smul)${txtblu}"monte_extract_results.sh $JOB_FILE --job_args=\"$JOB_ARGS\""$txtrst
    safe_exit 0
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 3e: Post-process, send the results
secho "$ME: Extracting results from $JOB_FILE"
if [ "$HOSTLESS" = "yes" ]; then
    vecho "monte_extract_results.sh -no --job_file=$JOB_FILE" 1
    monte_extract_results.sh -no --job_file=$JOB_FILE  --job_args="$JOB_ARGS"
else
    vecho "monte_extract_results.sh --job_file=$JOB_FILE --job_args=\"$JOB_ARGS\"" 1
    monte_extract_results.sh --job_file=$JOB_FILE  --job_args="$JOB_ARGS"
fi
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    vexit "error extracting the results. Recieved exit code $EXIT_CODE with monte_extract_results.sh -v=$VERBOSE --job_file=$JOB_FILE  --job_args=\"$JOB_ARGS\"" 6
fi

echo $txtgrn"      Results extracted" $txtrst

safe_exit 0
