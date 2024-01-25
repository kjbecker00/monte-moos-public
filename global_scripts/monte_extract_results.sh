#!/bin/bash
# Kevin Becker, May 26 2023

# Script used to extract results from a job.
ME="monte_extract_results.sh"
TEST="no"
OFFLOAD="yes"
RSYNC_TIMEOUT=120
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --job_file= [OPTIONS]"
        echo "                                                          "
        echo " This is a script used to extract results from a job by    "
        echo " finding the mission hash and running the job's "
        echo " post_process_results.sh script. "
        echo "                                                          "
        echo "Options:                                                   "
        echo " --help, -h Show this help message                         "
        echo " --noffload, -no No offloading of results to the host     "
        echo " --job_file=   used to specify an output directory.         "
        echo "               If not specified, the first flag-less argument   "
        echo "               is assumed to be the JOB_FILE.   "
        echo " --test, -t   use to test your job's post_process_results  "
        echo "              script. Sets verbosity to 1 (if not already  "
        echo "              set) and doesn't push the results to the host."
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_args="* ]]; then
        JOB_ARGS="${ARGI#*=}"
    elif [[ "${ARGI}" = "--test" || "${ARGI}" = "-t" ]]; then
        TEST="yes"
    elif [[ "${ARGI}" = "--noffload" || "${ARGI}" = "-no" ]]; then
        OFFLOAD="no"
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
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

# Set test mode
if [ $TEST = "yes" ]; then
    if [ $VERBOSE -eq 0 ]; then
        VERBOSE=1
    fi
    OFFLOAD="no"
fi

# Check the shell enviornment
monte_check_job.sh
if [ $? -ne 0 ]; then
    vexit "Enviornment has errors. Please fix them before running this script." 1
fi

#-------------------------------------------------------
#  Part 2: Source job File
#-------------------------------------------------------
if [ ! -f $JOB_FILE ]; then
    vexit "No job file found. Use -h or --help for help with this script" 1
fi
. "$JOB_FILE" $JOB_ARGS
if [[ $? -ne 0 ]]; then
    vexit "Sourcing job file yeilded non-zero exit code" 4
fi

# Add all the extra repos to the path
add_repo "moos-ivp"
add_extra_repos_to_path
add_repo "$SHORE_REPO"

#-------------------------------------------------------
# Part 2.5: Determine the job directory (to put the results in)
#-------------------------------------------------------
FULL_JOB_PATH=$(pwd)/$JOB_FILE
JOB_FILE_NAME=$(job_filename $JOB_FILE)
JOB_PATH="$(job_path $FULL_JOB_PATH)"
JOB_DIR="$(job_dirname $JOB_FILE)"

# If there is no parent directory named "job_dirs", then classify it as a misc job
if [[ "$JOB_DIR" -eq "$JOB_FILE_NAME" || "$JOB_PATH" -eq "$FULL_JOB_PATH" ]]; then
    JOB_DIR="misc_jobs"
fi
vecho "FULL_JOB_PATH=$FULL_JOB_PATH" 1
vecho "JOB_FILE=$JOB_FILE" 2
vecho "JOB_PATH=$JOB_PATH" 2
vecho "JOB_DIR=$JOB_DIR" 2



#-------------------------------------------------------
#  Part 3: Save to a directory on the local machine
#-------------------------------------------------------
#  Part 3a: find the shore alog
#-------------------------------------------------------
if [[ -d $MONTE_MOOS_CLIENT_REPOS_DIR/$SHORE_REPO ]]; then
    vecho "Found shore repo: $MONTE_MOOS_CLIENT_REPOS_DIR/$SHORE_REPO" 1
else
    vexit "Shore repo not found: $MONTE_MOOS_CLIENT_REPOS_DIR/$SHORE_REPO. Be sure to run the job first with monte_run_job.sh" 10
fi


SHORE_ALOG=$(find "${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/${SHORE_MISSION}" -maxdepth 4 -type f -iname "*SHORE*.alog" 2>/dev/null | head -1)
if [ ! -f "$SHORE_ALOG" ]; then
    vecho "shore alog not found in ${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/${SHORE_MISSION} -maxdepth 4 -type f -iname *SHORE*.alog" 2
    SHORE_ALOG=$(find "${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/${SHORE_MISSION}" -maxdepth 4 -type f -iname "*.alog" 2>/dev/null | head -1)
    if [ ! -f "$SHORE_ALOG" ]; then
        vecho "shore alog not found in ${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/${SHORE_MISSION} -maxdepth 4 -type f -iname *.alog" 2
        SHORE_ALOG=$(find "${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/trunk/${SHORE_MISSION}"  -maxdepth 4 -type f -iname "*SHORE*.alog" 2>/dev/null | head -1)
        if [ ! -f "$SHORE_ALOG" ]; then
            vecho "shore alog not found in ${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/trunk/${SHORE_MISSION} -maxdepth 4 -type f -iname \"*SHORE*.alog\"" 2
            if [ $TEST = "yes" ]; then
                vecho "${txtred} Error: No alog found in ${MONTE_MOOS_CLIENT_REPOS_DIR}/${SHORE_REPO}/${SHORE_MISSION}" 0
                vecho "${txtred} Error: Be sure you have run job first with the following script:" 0
                vecho "${txtred} Error: $(tput smul)monte_run_job.sh ${JOB_FILE}" 0
                vecho "Continuing anyway, but this may fail later on" 
            fi
        fi
    fi
fi
vecho "Shore alog = $SHORE_ALOG" 1

#-------------------------------------------------------
#  Part 3b: get the hash from the alog, or generate one
#-------------------------------------------------------
# Get the hash from the alog
if [[ -f $SHORE_ALOG ]]; then
    if [[ -f ${MONTE_MOOS_CLIENT_REPOS_DIR}/moos-ivp/ivp/bin/aloggrep ]]; then
        hash=$(${MONTE_MOOS_CLIENT_REPOS_DIR}/moos-ivp/ivp/bin/aloggrep ${SHORE_ALOG} MISSION_HASH --v --final --format=val --subpat=mhash)
    fi
    if [[ -f ${MONTE_MOOS_CLIENT_REPOS_DIR}/moos-ivp/trunk/ivp/bin/aloggrep ]]; then
        hash=$(${MONTE_MOOS_CLIENT_REPOS_DIR}/moos-ivp/trunk/ivp/bin/aloggrep ${SHORE_ALOG} MISSION_HASH --v --final --format=val --subpat=mhash)
    fi
    
    if [ $? -ne 0 ]; then
        hash=""
        echo "${txtylw}Warning: aloggrep failed to retrieve a hash. Generating a hash${txtrst}"
    fi
fi
#-------------------------------------------------------
# Makes a hash if not found. Useful if pMissionHash hasn't been added
if [ -z $hash ]; then
    current_time=$(date +%y%m%d-%H%M)
    seconds=$(date +%S)
    hash="${current_time}-${seconds}-$RANDOM"
fi
vecho "Hash = $hash" 1
LOCAL_RESULTS_DIR="${CARLO_DIR_LOCATION}/results"


#-------------------------------------------------------
# Set the results directory on the host
#-------------------------------------------------------

LOCAL_JOB_RESULTS_DIR="${LOCAL_RESULTS_DIR}/${JOB_DIR}/${JOB_FILE_NAME}/${JOB_FILE_NAME}_${hash}"
HOST_RESULTS_FULL_DIR="${MONTE_MOOS_HOST_RECIEVE_DIR}/results/${JOB_PATH}"
# Just for display purposes
LINK_TO_RESULTS="$MONTE_MOOS_HOSTNAME_FULL/${MONTE_MOOS_HOST_RESULTS_DIR}/${JOB_DIR}"

# If you're testing it, remove a prior iteration of the local results dir
if [ -d $LOCAL_JOB_RESULTS_DIR ] && [ $TEST = "yes" ]; then
    vecho "Testing, so removing old results dir" 1
    rm -rf $LOCAL_JOB_RESULTS_DIR
fi
if [[ ! -d $LOCAL_JOB_RESULTS_DIR ]]; then
    mkdir -p $LOCAL_JOB_RESULTS_DIR
fi

# Writes to an argfile, which saves the job name job args
echo "$JOB_FILE $JOB_ARGS" >> $LOCAL_JOB_RESULTS_DIR/.argfile

#-------------------------------------------------------
#  Part 4: Run post-processing script specific
#          to the job_dir
#-------------------------------------------------------
#********************************************************
#  Runs job-specific post-processing script here:
# Step 1: Find the post_process_results.sh script to use
results_script_directory="${JOB_FILE}"
while [[ ! -f "${results_script_directory}/post_process_results.sh" && "${results_script_directory}" != "job_dirs" ]]; do
    results_script_directory=$(dirname ${results_script_directory})
    if [[ $results_script_directory == $(dirname ${results_script_directory}) ]]; then
        break
    fi
done
if [ ! -f "${results_script_directory}/post_process_results.sh" ]; then
    vexit "No post_process_results.sh found in job_dirs/${JOB_DIR} or any parent directory" 2
fi

# Step 2: ensure it can be executed
chmod +x ${results_script_directory}/post_process_results.sh

# Step 3: Execute the script
vecho "$(tput bold)${txtylw}Using the script: $(tput smul)${results_script_directory}/post_process_results.sh Ensure this is the correct script" 1
if [[ $JOB_ARGS == "" ]]; then
    vecho "Running with these flags: $(tput smul)${results_script_directory}/post_process_results.sh --job_file=$JOB_FILE --local_results_dir=$LOCAL_JOB_RESULTS_DIR" 1
    ${results_script_directory}/post_process_results.sh --job_file="$JOB_FILE" --job_args="$JOB_ARGS" --local_results_dir="$LOCAL_JOB_RESULTS_DIR" # >& /dev/null
else
    vecho "Running with these flags: $(tput smul)${results_script_directory}/post_process_results.sh --job_file=$JOB_FILE --job_args=\"$JOB_ARGS\" --local_results_dir=$LOCAL_JOB_RESULTS_DIR" 1
    ${results_script_directory}/post_process_results.sh --job_file="$JOB_FILE" --job_args="$JOB_ARGS" --local_results_dir="$LOCAL_JOB_RESULTS_DIR" # >& /dev/null
fi


EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    vexit "${results_script_directory}/post_process_results.sh --job_file=\"$JOB_FILE\" --local_results_dir=\"$LOCAL_JOB_RESULTS_DIR\" exited with code: $EXIT_CODE " 2
fi
#********************************************************

if [ $TEST = "yes" ]; then
    # get everything before the first / in JOB_FILE
    yourdir="${JOB_DIR%%/*}"
    echo ""
    echo "-------------------------------------- Next Steps --------------------------------------"
    echo "${txtrst}Now, go into the directory: $(tput smul)${txtblu}$LOCAL_JOB_RESULTS_DIR${txtrst}"
    echo "Make ${txtbld}sure${txtrst} that the results look the way you want. Once you are sure,"
    echo "Copy your directory to $MONTE_MOOS_HOST: "
    echo "        $(tput smul)${txtblu}rsync -zaPr $(dirname $JOB_FILE) ${MONTE_MOOS_HOSTNAME_SSH}:${MONTE_MOOS_HOST_JOB_DIRS}/kerbs/desired/path ${txtrst}"
    echo ""
    echo "    Then, add this line to your ${MONTE_MOOS_HOSTNAME_SSH}:${MONTE_MOOS_HOST_QUEUE_FILES}/KERBS_job_queue.txt file on the host, and you should be all set!"
    echo "         ${JOB_DIR}/${JOB_FILE_NAME} 5 "
    echo ""
else
    vecho "Results saved to $(tput smul)${txtblu}${LOCAL_JOB_RESULTS_DIR}" 1
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 5: Send results to host, if desired
if [[ $OFFLOAD != "no" ]]; then
    vecho "Part 5: Offloading results $LOCAL_JOB_RESULTS_DIR $HOST_RESULTS_FULL_DIR " 5
    /${MONTE_MOOS_BASE_DIR}/scripts/send2host.sh $LOCAL_JOB_RESULTS_DIR $HOST_RESULTS_FULL_DIR
    [ $? -eq 0 ] || { vexit "send2host.sh $LOCAL_JOB_RESULTS_DIR $HOST_RESULTS_FULL_DIR failed with exit code $?" 3; }
    rm -rf $LOCAL_JOB_RESULTS_DIR
else
    vecho "Not offloading results" 1
fi
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -

exit 0
