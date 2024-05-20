#!/bin/bash
# Kevin Becker Jun 9 2023

ME="monte_check_job.sh"
# CLIENT="no"
TEST="no"

#-------------------------------------------------------
#  Part 0: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --job_file=[JOB_FILE]        "
        echo "                                                          "
        echo " Checks a job file for (some basic) errors. "
        echo " Note: If the job file itself returns a non-zero exit code,"
        echo "    this script will return that same exit code."
	echo " This does not check for more intracite errors, such as a "
	echo " mission moos-ivp-extend directory, or a missing mission. "
	echo " It is also worth noting that extra variables are ignored."
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --job_file=[FILE]    job file to be run"
        # echo " --client, -c         check as a client (check ssh-agent)"
        exit 0
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_args="* ]]; then
        JOB_ARGS="${ARGI#*=}"
    elif [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
        VERBOSE=1
    elif [[ "${ARGI}" = "--client" || "${ARGI}" = "-c" ]]; then
        CLIENT="yes"
    else
        # Job file provided without the flag
        # Assumed running as test
        if [ -z "$JOB_FILE" ]; then
            TEST="yes"
            if [[ $VERBOSE -eq 0 ]]; then
                VERBOSE=1
            fi
            JOB_FILE=$ARGI
        else
            echo "$ME.sh: Bad Arg: $ARGI "
            exit 1
        fi
    fi
done

#-------------------------------------------------------
#  Part 0.5: Check monte_info variables
#-------------------------------------------------------

# Check if monte-moos was added to path and carlo dir has been sourced
[[ -d $MONTE_MOOS_BASE_DIR ]] || {
    echo "MONTE_MOOS_BASE_DIR ($MONTE_MOOS_BASE_DIR) Does not exist. Should be set in ~/.bashrc or equivalent"
    exit 30
}

which monte_check_job.sh >/dev/null || {
    echo "MONTE_MOOS_BASE_DIR ($MONTE_MOOS_BASE_DIR) not added to path"
    exit 31
}

#-------------------------------------------------------
# Now that the path is set, we can import the proper
# utils
#-------------------------------------------------------
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"

# Variables to be set for BOTH the host and the client
[[ -d $CARLO_DIR_LOCATION ]] || { vexit "CARLO_DIR_LOCATION ($CARLO_DIR_LOCATION) does not exist. Should be set in ~/.bashrc or equivalent" 30; }
[[ -n $MONTE_MOOS_HOST ]] || { vexit "MONTE_MOOS_HOST ($MONTE_MOOS_HOST) not set. Did you add \"source ${CARLO_DIR_LOCATION}/monte_info\" to your ~/.bashrc or equivalent?" 30; }
[[ -n $MONTE_MOOS_HOST_RECIEVE_DIR ]] || { vexit "MONTE_MOOS_HOST_RECIEVE_DIR ($MONTE_MOOS_HOST_RECIEVE_DIR) not set" 30; }
[[ -n $MONTE_MOOS_HOST_JOB_DIRS ]] || { vexit "MONTE_MOOS_HOST_JOB_DIRS ($MONTE_MOOS_HOST_JOB_DIRS) not set" 30; }
[[ -n $MONTE_MOOS_HOST_QUEUE_FILES ]] || { vexit "MONTE_MOOS_HOST_QUEUE_FILES ($MONTE_MOOS_HOST_QUEUE_FILES) not set" 30; }

if [[ $MYNAME == "$MONTE_MOOS_HOST" ]]; then
    vecho "Checking as host" 1
    # Variables to be set for the HOST only
    [[ -n $MONTE_MOOS_HOST_WEB_ROOT_DIR ]] || { vexit "MONTE_MOOS_HOST_WEB_ROOT_DIR ($MONTE_MOOS_HOST_WEB_ROOT_DIR) not set" 30; }
    # Checks for the HOST only
    [[ -d $MONTE_MOOS_HOST_RECIEVE_DIR ]] || { vexit "MONTE_MOOS_HOST_RECIEVE_DIR ($MONTE_MOOS_HOST_RECIEVE_DIR) does not exist" 30; }
    [[ -d $MONTE_MOOS_HOST_JOB_DIRS ]] || { vexit "MONTE_MOOS_HOST_JOB_DIRS ($MONTE_MOOS_HOST_JOB_DIRS) does not exist" 30; }
    [[ -d $MONTE_MOOS_HOST_QUEUE_FILES ]] || { vexit "MONTE_MOOS_HOST_QUEUE_FILES ($MONTE_MOOS_HOST_QUEUE_FILES) does not exist" 30; }
else
    vecho "Checking as client" 1
    # Variables to be set for the CLIENT only (may vary from client to client)
    [[ -f $MONTE_MOOS_BASE_REPO_LINKS ]] || { vexit "MONTE_MOOS_BASE_REPO_LINKS ($MONTE_MOOS_BASE_REPO_LINKS) not set" 30; }
    [[ -d "$(dirname "$MONTE_MOOS_CLIENT_REPOS_DIR")" ]] || { vexit "MONTE_MOOS_CLIENT_REPOS_DIR ($MONTE_MOOS_CLIENT_REPOS_DIR) does not exist" 30; }
    [[ -n $MONTE_MOOS_HOST_URL_WGET ]] || { vexit "MONTE_MOOS_HOST_URL_WGET ($MONTE_MOOS_HOST_URL_WGET) not set" 30; }
    [[ -n $MONTE_MOOS_HOSTNAME_SSH ]] || { vexit "MONTE_MOOS_HOSTNAME_SSH ($MONTE_MOOS_HOSTNAME_SSH) not set" 30; }
    [[ -n $MONTE_MOOS_HOST_SSH_KEY ]] || { vexit "MONTE_MOOS_HOST_SSH_KEY ($MONTE_MOOS_HOST_SSH_KEY) not set" 30; }
    [[ -n $MONTE_MOOS_WGET_BASE_DIR ]] || { vexit "MONTE_MOOS_WGET_BASE_DIR ($MONTE_MOOS_WGET_BASE_DIR) not set" 30; }
fi

#-------------------------------------------------------
#  Part 0.5: Checking ssh
#-------------------------------------------------------
if [ "$MYNAME" != "$MONTE_MOOS_HOST" ]; then
    "${MONTE_MOOS_BASE_DIR}/client_scripts/send2host.sh" --test
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        vexit " with ssh (exit code $EXIT_CODE). If you are not using the current computer as the client, feel free to continue" 14
    fi
fi

#-------------------------------------------------------
#  Part 1: Check if job exists
#-------------------------------------------------------
if [ -f "$JOB_FILE" ]; then
    vecho "Job file exists" 1
else
    vecho "${txtgry}$ME: Passed enviornment check! $txtrst" 1
    exit 0
fi

vecho "Attempting to source job file" 1
vecho "Job file = $JOB_FILE" 1
vecho "Job args = $JOB_ARGS" 1
. "$JOB_FILE" $JOB_ARGS
if [[ $? -ne 0 ]]; then
    vexit "Sourcing job file yeilded non-zero exit code" 4
fi
vecho "Job file exit code = 0 (good)" 1
if [ -z "$MONTE_MOOS_HOSTNAME_SSH" ]; then
    vexit "MONTE_MOOS_HOSTNAME_SSH ($MONTE_MOOS_HOSTNAME_SSH) not set" 5
fi

#-------------------------------------------------------
#  Part 2: Check vehicle counts
#-------------------------------------------------------
if [[ $VEHICLES -gt 0 ]]; then
    [ "$VEHICLES" = ${#VEHICLE_REPOS[@]} ] || { vexit "VEHICLES ($VEHICLES) does not match number of VEHICLE_REPOS (${#VEHICLE_REPOS[@]})" 6; }
    [ "$VEHICLES" = ${#VEHICLE_MISSIONS[@]} ] || { vexit "VEHICLES ($VEHICLES) does not match number of VEHICLE_MISSIONS (${#VEHICLE_MISSIONS[@]})" 7; }

    if [[ -z "$VEHICLE_FLAGS" ]]; then
        echo "${txtylw}$0 Warning, VEHICLE_FLAGS array ($VEHICLE_FLAGS) is empty${txtrst}"
    else
        [ "$VEHICLES" = ${#VEHICLE_MISSIONS[@]} ] || { vexit "VEHICLES ($VEHICLES) does not match number of VEHICLE_FLAGS (${#VEHICLE_FLAGS[@]})" 8; }
    fi
    vecho "Vehicle count good" 1
else
    vecho "No vehicles to check" 1
fi

#-------------------------------------------------------
#  Part 3: Check that shoreside is set
#-------------------------------------------------------
[ -n "$SHORE_FLAGS" ] || { echo "${txtylw}$0 Warning, SHORE_FLAGS ($SHORE_FLAGS) is empty${txtrst}"; }
[ -n "$SHORE_REPO" ] || { vexit "SHORE_REPO ($SHORE_REPO) must be set" 9; }
[ -n "$SHORE_MISSION" ] || { vexit "SHORE_MISSION ($SHORE_MISSION) must be set" 10; }
vecho "Shoreside variables set" 1

#-------------------------------------------------------
#  Part 4: Check that there is a job timeout
#-------------------------------------------------------
[[ -n "$JOB_TIMEOUT" ]] || { vexit "JOB_TIMEOUT ($JOB_TIMEOUT) not set" 12; }
[ "$JOB_TIMEOUT" -gt 1 ] || { vexit "JOB_TIMEOUT ($JOB_TIMEOUT) not greater than one" 12; }
vecho "JOB_TIMEOUT set" 1

#-------------------------------------------------------
#  Done!
#-------------------------------------------------------
echo $txtrst $txtgrn "Job file is good" $txtrst
if [ $TEST = "yes" ]; then
    if [[ $JOB_ARGS == "" ]]; then
        vecho "${txtrst}Now try running the job with: $(tput smul)${txtblu}monte_run_job.sh ${JOB_FILE} ${txtrst} " 0
    else
        vecho "${txtrst}Now try running the job with: $(tput smul)${txtblu}monte_run_job.sh ${JOB_FILE} --job_args=\"$JOB_ARGS\"${txtrst} " 0
    fi
fi

exit 0
