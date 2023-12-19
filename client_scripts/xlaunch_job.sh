#!/bin/bash
# Kevin Becker, May 26 2023
#-----------------------------------------------------
#  Part 1: Handle command line arguments
#-----------------------------------------------------
QUIET="yes"
UQUERY_TRIES=2
ME=$(basename "$0")
VERBOSE=0
TIMER_ONLY="no"
OLD_PATH=$PATH
OLD_DIRS=$IVP_BEHAVIOR_DIRS
txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey

# Initial poke to start the mission
START_POKE="DEPLOY_ALL=true DEPLOY=true MOOS_MANUAL_OVERRIDE_ALL=false "
START_POKE+="MOOS_MANUAL_OVERIDE_ALL=false MOOS_MANUAL_OVERRIDE=false "
START_POKE+="MOOS_MANUAL_OVERIDE=false RETURN_ALL=false RETURN=false "

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
        echo "${txtred}$ME Exiting safely. Resetting PATH and IVP_BEHAVIOR_DIRS and running ktm... ${txtrst}"
        ktm >&/dev/null
    fi
    exit $1
}
trap ctrl_c INT
ctrl_c() {
    safe_exit 130
}

check_uquerydb(){
    local QUERY_MODE="a"
    SHORE_TARG=$1
    if [[ "${QUERY_MODE}" = "a" ]]; then
        uQueryDB --alias="mm-query" $SHORE_TARG &>/dev/null
        EXIT_CODE=$?
        OUTPUT=$EXIT_CODE
    fi

    vecho "                                                                  uQueryDB (mode $QUERY_MODE) output: $OUTPUT" 3
    return $OUTPUT
}
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME [OPTIONS] "
        echo "Launches shoreside, vehicles, and pokes the mission. "
        echo "Runs uQueryDB & a timer to check if the mission has completed "
        echo "Options: "
        echo " --help, -h Show this help message "
        echo " --job_file=<job> file with all parameters"
        echo "  --quiet, -q        Quiet uQueryDB, uPokeDB                 "
        echo "  --verbose=, -v=      Set verbosity                 "
        echo "  --verbose, -v        Set verbosity=1                 "
        safe_exit 0
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_args="* ]]; then
        JOB_ARGS="${ARGI#*=}"
    elif [ "${ARGI}" = "--quiet" -o "${ARGI}" = "-q" ]; then
        QUIET="yes"
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        FLOW_DOWN_ARGS+="${ARGI} "
    fi
done

#-----------------------------------------------------
#  Part 2: Read parameter files
#-----------------------------------------------------
if [ -z $JOB_FILE ]; then
    vexit "No job file set" 1
fi
if [ ! -f $JOB_FILE ]; then
    vexit "job file $JOB_FILE not found" 1
fi

. "$JOB_FILE" $JOB_ARGS
if [[ $? -ne 0 ]]; then
    vexit "Sourcing job file yeilded non-zero exit code" 4
fi

#-------------------------------------------------------
#  Part 3: Add MOOS-IVP to path, export DIRS
#          needed if run in ssh
#-------------------------------------------------------
if type MOOSDB >/dev/null 2>&1; then
    true
else
    vecho "Adding moos-dirs/moos-ivp/bin, scripts, ivp/scripts to $PATH..." 1
    OLD_PATH=$PATH
    PATH=$PATH:$PWD/moos-dirs/moos-ivp/bin
    PATH=$PATH:$PWD/moos-dirs/moos-ivp/scripts
    PATH=$PATH:$PWD/moos-dirs/moos-ivp/ivp/scripts
    export PATH
fi

#-----------------------------------------------------
#  Part 4: Set the defaults
#-----------------------------------------------------
if [ -z $VEHICLES ]; then
    VEHICLES=0
fi
if [ -z $SHORESIDE_SCRIPT ]; then
    if (($VEHICLES > 0)); then
        SHORESIDE_SCRIPT="launch_shoreside.sh"
    else
        SHORESIDE_SCRIPT="launch.sh"
    fi
fi
if [ -z $VEHICLE_SCRIPTS ]; then
    VEHICLE_SCRIPTS=()
    for ((i = 0; i < $VEHICLES; i++)); do
        VEHICLE_SCRIPTS+=("launch_vehicle.sh")
    done

fi
REPO_DIR="${PWD}/moos-dirs/"

#-----------------------------------------------------
#  Part 5: Check job parameter file
#-----------------------------------------------------
if (($VEHICLES > 0)); then
    if ((${#VEHICLE_MISSIONS[@]} != $VEHICLES)); then
        vexit "Length of VEHICLE_MISSIONS does not match number of vehicles" 3
    fi
    if ((${#VEHICLE_SCRIPTS[@]} != $VEHICLES)); then
        vexit "Length of VEHICLE_SCRIPTS does not match number of vehicles" 3
    fi
    if ((${#VEHICLE_FLAGS[@]} != $VEHICLES)); then
        vexit "Length of VEHICLE_FLAGS does not match number of vehicles" 3
    fi
fi

#-----------------------------------------------------
#  Part 6: Source additional repos before launch
#-----------------------------------------------------
#  Part 6a: EXTRA_REPOS
EXTRA_REPO_COUNT=${#EXTRA_REPOS[@]}
for ((i = 0; i < EXTRA_REPO_COUNT; i++)); do
    vecho "Sourcing ${EXTRA_REPOS[i]}..." 1
    repo="${EXTRA_REPOS[i]}"
    if [[ "$repo" == "~/"* ]]; then
        repo="${repo/#\~/$HOME}"
    else
        repo="${REPO_DIR}${repo}"
    fi
    if [ -d ${repo}/bin ]; then
        PATH+=":${repo}/bin"
    else
        vexit "Missing ${repo}/bin from moos-dirs. Try adding this repo to $(tput smul)repo_links.txt$(tput rmul)" 7
    fi
    if [ -d ${repo}/lib ]; then
        IVP_BEHAVIOR_DIRS+=":${repo}/lib"
    else
        vexit "Missing ${repo}/bin from moos-dirs. Try adding this repo to $(tput smul)repo_links.txt$(tput rmul)" 7
    fi
done
#  Part 6b: Extra binaries
EXTRA_BIN_COUNT=${#EXTRA_BIN_REPOS[@]}
for ((i = 0; i < EXTRA_BIN_COUNT; i++)); do
    vecho "Sourcing ${EXTRA_BIN_REPOS[i]}..." 1
    repo="${EXTRA_BIN_REPOS[i]}"
    if [[ "$repo" == "~/"* ]]; then
        repo="${repo/#\~/$HOME}"
    else
        repo="${REPO_DIR}${repo}"
    fi
    if [ -d ${repo}/bin ]; then
        PATH+=":${repo}/bin"
    else
        vexit "Missing ${repo}/bin from moos-dirs. Try adding this repo to $(tput smul)repo_links.txt$(tput rmul)" 7
    fi
done
#  Part 6c: Extra libraries for ivp behaviors
EXTRA_LIB_COUNT=${#EXTRA_LIB_REPOS[@]}
for ((i = 0; i < EXTRA_LIB_COUNT; i++)); do
    vecho "Sourcing ${EXTRA_LIB_REPOS[i]}..." 1
    repo="${EXTRA_LIB_REPOS[i]}"
    if [[ "$repo" == "~/"* ]]; then
        repo="${repo/#\~/$HOME}"
    else
        repo="${REPO_DIR}${repo}"
    fi
    if [ -d ${repo}/lib ]; then
        IVP_BEHAVIOR_DIRS+=":${repo}/lib"
    else
        vexit "Missing ${repo}/bin from moos-dirs. Try adding this repo to $(tput smul)repo_links.txt$(tput rmul)" 7
    fi
done
vecho "IVP_BEHAVIOR_DIRS=$IVP_BEHAVIOR_DIRS" 1
vecho "PATH=$PATH" 2

#-----------------------------------------------------
#  Part 6.5: Clean directory
#-----------------------------------------------------
FULL_MISSION_DIR=moos-dirs/${SHORE_REPO}/${SHORE_MISSION}
if [[ ! -d $FULL_MISSION_DIR ]]; then
    if [[ -d moos-dirs/${SHORE_REPO}/trunk/${SHORE_MISSION} ]]; then
        FULL_MISSION_DIR=moos-dirs/${SHORE_REPO}/trunk/${SHORE_MISSION}
    fi
fi
cd $FULL_MISSION_DIR
if [ -f clean.sh ]; then
    ./clean.sh
fi
cd - >&/dev/null


#-----------------------------------------------------
#  Part 7: Launch shoreside
#-----------------------------------------------------

vecho "Part 1: Launching the shoreside mission... " 1
vecho "             shoreside script: $SHORESIDE_SCRIPT" 1
vecho "             shoreside repo: $SHORE_REPO" 1
vecho "             shoreside mission: $SHORE_MISSION" 1
vecho "             shoreside flags: $SHORE_FLAGS" 1
vecho "./client_scripts/source_launch.sh --script=${SHORESIDE_SCRIPT} --repo=${SHORE_REPO} --mission=${SHORE_MISSION}  -v=$VERBOSE ${SHORE_FLAGS}" 2
./client_scripts/source_launch.sh --script="${SHORESIDE_SCRIPT}" --repo="${SHORE_REPO}" --mission="${SHORE_MISSION}" -v=$VERBOSE ${SHORE_FLAGS}
LEXIT_CODE=$?
if [ $LEXIT_CODE != 0 ]; then
    vexit " ./client_scripts/source_launch.sh --script=${SHORESIDE_SCRIPT} --repo=${SHORE_REPO} --mission=${SHORE_MISSION} ${SHORE_FLAGS} returned non-zero exit code:  $LEXIT_CODE" 4
fi

#-----------------------------------------------------
#  Part 8: Launch vehicles
#-----------------------------------------------------
for ((i = 0; i < VEHICLES; i++)); do
    vecho "Part 1b: Launching vechicle $i..." 1
    vecho "             vehicle script: ${VEHICLE_SCRIPTS[i]}" 1
    vecho "             vehicle repo: ${VEHICLE_REPOS[i]}" 1
    vecho "             vehicle mission: ${VEHICLE_MISSIONS[i]}" 1
    vecho "             vehicle flags: ${VEHICLE_FLAGS[i]}" 1
    vecho "             shared vehicle flags: $SHARED_VEHICLE_FLAGS" 1
    vecho "./client_scripts/source_launch.sh --script="${VEHICLE_SCRIPTS[i]}" --repo="${VEHICLE_REPOS[i]}" --mission="${VEHICLE_MISSIONS[i]}" ${VEHICLE_FLAGS[i]} ${SHARED_VEHICLE_FLAGS}" 2
    ./client_scripts/source_launch.sh --script="${VEHICLE_SCRIPTS[i]}" --repo="${VEHICLE_REPOS[i]}" --mission="${VEHICLE_MISSIONS[i]}" -v=$VERBOSE ${VEHICLE_FLAGS[i]} ${SHARED_VEHICLE_FLAGS}
    LEXIT_CODE=$?
    if [ $LEXIT_CODE != 0 ]; then
        vexit " ./client_scripts/source_launch.sh --script="${VEHICLE_SCRIPTS[i]}" --repo="${VEHICLE_REPOS[i]}" --mission="${VEHICLE_MISSIONS[i]}"  -v=$VERBOSE ${VEHICLE_FLAGS[i]} ${SHARED_VEHICLE_FLAGS} returned non-zero exit code:  $LEXIT_CODE" 5
    fi
done

#-------------------------------------------------------
#  Part 9: Check targ_shoreside.moos exists, set other defaults
#-------------------------------------------------------
# If no SHORE_TARG, set the default
if [ -z $SHORE_TARG ]; then
    SHORE_TARG="targ_shoreside.moos"
fi
# Allow some time for the shore targ to generate
COUNT=0
while [ "$COUNT" -lt 30 ]; do
    vecho "   Waiting for shore targ to generate... " 1
    if [ -f $SHORE_TARG ]; then
        break
    fi
    # If SHORE_TARG is not found, check the shoreside mission directory
    if [ -f "moos-dirs/${SHORE_REPO}/${SHORE_MISSION}/${SHORE_TARG}" ]; then
        SHORE_TARG="moos-dirs/${SHORE_REPO}/${SHORE_MISSION}/${SHORE_TARG}"
        break
    fi
    # Check trunk directory
    if [ -f "moos-dirs/${SHORE_REPO}/trunk/${SHORE_MISSION}/${SHORE_TARG}" ]; then
        SHORE_TARG="moos-dirs/${SHORE_REPO}/trunk/${SHORE_MISSION}/${SHORE_TARG}"
        break
    fi
    sleep 1
    COUNT=$(($COUNT + 1))
done

# If SHORE_TARG is still not found, exit
if [ ! -f "$SHORE_TARG" ]; then
    ktm
    vecho "SHORE_REPO=$SHORE_REPO" 1
    vecho "SHORE_MISSION=$SHORE_MISSION" 1
    vecho "SHORE_TARG=$SHORE_TARG" 1
    vexit "Missing shoreside targ file. Tried ${SHORE_TARG} and moos-dirs/${SHORE_REPO}/${SHORE_MISSION}/${SHORE_TARG} and moos-dirs/${SHORE_REPO}/trunk/${SHORE_MISSION}/${SHORE_TARG}" 6
else
    vecho "   shore targ $SHORE_TARG found" 1
fi

if [ -z "$DELAY_POKE" ]; then
    DELAY_POKE=5
fi

#-------------------------------------------------------
#  Part 10: Start the mission with the right pokes
#-------------------------------------------------------
vecho "Part 2: Poking/Starting mission in $DELAY_POKE seconds... " 1
sleep $DELAY_POKE
vecho "            poking... " 1
if [ "${QUIET}" = "yes" ]; then
    vecho "uPokeDB $SHORE_TARG $START_POKE >&/dev/null" 2
    uPokeDB $SHORE_TARG $START_POKE >&/dev/null
else
    vecho "uPokeDB $SHORE_TARG $START_POKE" 2
    uPokeDB $SHORE_TARG $START_POKE
fi

#-------------------------------------------------------
#  Part 11: Keep checking if the mission until it is done
#          and bring it down when complete
#-------------------------------------------------------
vecho "Part 3: Query the mission for halt conditions" 1
echo ""
valid_uquerydb="yes"
start_time=$(date +%s)
first_iter="yes"

while [ 1 ]; do

    rm -f .checkvars

    #-----------------------------------------------------
    # Check for halt conditions
    #-----------------------------------------------------
    if [[ $TIMER_ONLY = "yes" ]]; then
        vecho "Timer only mode. Not querying..." 1
        : # no-op. Will get checked later
    else
        if [[ $valid_uquerydb = "yes" ]]; then
            vecho "uQueryDB $SHORE_TARG " 2
            uQueryDB $SHORE_TARG &>/dev/null
            QUERY=$?
            vecho "output of query: $QUERY" 2

            if [ $QUERY -eq 1 ]; then
                vecho "Continuing mission..." 2
            fi

            if [ $QUERY -eq 0 ]; then
                current_time=$(date +%s)
                elapsed_time=$(($current_time - $start_time))
                if [ $first_iter = "yes" ]; then
                    valid_uquerydb="no"
                    first_iter="no"
                    vecho "Empty uQueryDB. Resorting to only using the timer..." 2
                else
                    first_iter="no"
                    echo "${txtgrn}      Mission completed after ${elapsed_time} seconds${txtrst}"
                    break
                fi
            fi
        else
            vecho "Invalid uQueryDB (failed on first iter)" 2
        fi
    fi

    # Check timer, exit if necessary
    current_time=$(date +%s)
    elapsed_time=$(($current_time - $start_time))
    vecho "     elapsed time=$elapsed_time (timeout=$JOB_TIMEOUT)" 2


    if [ $(( elapsed_time % 60 )) -eq 0 ]; then
        secho "Still runnig $JOB_FILE ($elapsed_time/$JOB_TIMEOUT seconds elapsed)" >&/dev/null
    fi

    #-----------------------------------------------------
    # Update timer
    #-----------------------------------------------------
    # if [ $valid_uquerydb = "no" ]; then
    bar_width=40
    progress=$(echo "$bar_width/$JOB_TIMEOUT*$elapsed_time" | bc -l)
    fill=$(printf "%.0f\n" $progress)
    if [ $fill -gt $bar_width ]; then
        fill=$bar_width
    fi
    empty=$(($fill - $bar_width))
    percent=$(echo "100/$JOB_TIMEOUT*$elapsed_time" | bc -l)
    percent=$(printf "%0.2f\n" $percent)
    if [ $(echo "$percent>100" | bc) -gt 0 ]; then
        percent="100.00"
    fi

    #- - - - - - - - - - - - - - - - - - - - -
    # check if darwin/macos vs linux
    if [ "$(uname)" == "Darwin" ]; then
        printf "\r      "
        printf "%${fill}s" '' | tr ' ' ░
        printf "%${empty}s" '' | tr ' ' ▉
    else
        printf "\r      ["
        printf "%${fill}s" ''
        printf "%${empty}s" '' | tr ' ' '='
        printf "]"
    fi
    printf " $percent%% (${elapsed_time}/${JOB_TIMEOUT} sec)"
    if [ $valid_uquerydb = "no" ]; then
        printf " \e[33mWarning: uQueryDB failed. Using timer \e[0m"
    fi
    # fi

    # Check timer, exit if necessary
    if [ $elapsed_time -gt $JOB_TIMEOUT ]; then
        echo ""
        echo "${txtylw}      Mission timed out after ${elapsed_time} seconds${txtrst}"
        break
    fi

    #-----------------------------------------------------
    # Sleep, if uQueryDB has too short of a wait time
    #-----------------------------------------------------
    sleep 1
    first_iter="no"

done

vecho "Part 4: Bringing down the mission... " 1
ktm >&/dev/null
killall pAntler >&/dev/null
sleep 1
# Kills ALL child processes
pkill -P $$
sleep 1
PATH=$OLD_PATH
export PATH

safe_exit 0
