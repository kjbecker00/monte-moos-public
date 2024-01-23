#!/bin/bash
# Kevin Becker, May 26 2023

# Script used to publish files to the host
ME="send2host.sh"
DELETE="no"
LOCAL_PATH=""
HOST_PATH=""
SSH_HOST="$MONTE_MOOS_USERNAME@$MONTE_MOOS_HOSTNAME_SSH"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh local_dir host_dir [OPTIONS]"
        echo "                                                          "
        echo " Used to publish files to the host. Essentially a wrapper "
        echo " for rsync. Used by secho.sh, extract_results.sh and others..."
        echo "                                                          "
        echo "Options:                                                   "
        echo " --help, -h Show this help message                         "
        echo " --delete, -d Delete the file on the host                         "
        echo " --test, -t Test the ssh connection                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" == "--delete" || "${ARGI}" == "-d" ]]; then
        DELETE="yes"
    elif [[ "${ARGI}" == "--test" || "${ARGI}" == "-t" ]]; then
        TEST="yes"
    else
        if [ -z "$LOCAL_PATH" ]; then
            LOCAL_PATH="${ARGI}"
        elif [ -z "$HOST_PATH" ]; then
            HOST_PATH="${ARGI}"
        else
            vexit "Bad Arg: $ARGI " 1
        fi
    fi
done


# check for required args
if [[ $TEST != "yes" ]]; then
    if [[ -z $LOCAL_PATH ]]; then
        vexit "missing path to what you want to copy/delete!" 2
    fi
    if [[ $DELETE = "yes" ]]; then
        vecho "delete mode" 1
        HOST_PATH="$LOCAL_PATH"
        LOCAL_PATH=""
    fi
    if [[ -z $HOST_PATH ]]; then
        vexit "missing host path, and not in delete mode" 2
    fi
fi

#-------------------------------------------------------
#  Part 2: Check ssh key
#-------------------------------------------------------
# Check for ssh key
if [ -f $MONTE_MOOS_HOST_SSH_KEY ]; then
    chmod -R go-rwx $MONTE_MOOS_HOST_SSH_KEY &>/dev/null
fi

#-------------------------------------------------------
#  Part 3: Start ssh agent
#-------------------------------------------------------
eval $(ssh-agent -s) &>/dev/null
ps -p $SSH_AGENT_PID &>/dev/null
SSH_AGENT_RUNNING=$?
if [ ${SSH_AGENT_RUNNING} -ne 0 ]; then
    vexit "Unable to start ssh-agent" 3
fi

#-------------------------------------------------------
#  Part 4: Add ssh key
#-------------------------------------------------------
ssh-add -t 7200 $MONTE_MOOS_HOST_SSH_KEY 2>/dev/null
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne "0" ]; then
    vexit "ssh agent unable to add ssh key" 3
fi

#-------------------------------------------------------
#  Part 5: If test mode, exit
#-------------------------------------------------------
if [[ $TEST == "yes" ]]; then
    kill -9 $SSH_AGENT_PID
    exit 0
fi # end test

#-------------------------------------------------------
#  Part 6-7: Perform action on host (copy or delete)
#-------------------------------------------------------
if [[ $DELETE != "yes" ]]; then
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 6A: Make dir on host
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    echo "${txtgry}      ${LOCAL_PATH}${txtblu} → ${txtbld}${SSH_HOST}:${txtrst}${HOST_PATH}${txtrst}"
    if [ -d $LOCAL_PATH ]; then
        DIR_TO_MAKE="$HOST_PATH"
    else
        DIR_TO_MAKE="$(dirname $HOST_PATH)"
    fi
    vecho "making dir $DIR_TO_MAKE on host" 2
    ssh -n ${SSH_HOST} "mkdir -p $DIR_TO_MAKE" 
    EXIT_CODE=$?
    if [ ! $EXIT_CODE -eq "0" ]; then
        if [ $EXIT_CODE -eq 255 ]; then
            echo $txtylw"      warning: ssh unable to connect. Continuing..."$txtrst
        else
            vexit "ssh -n ${SSH_HOST} mkdir -p $HOST_PATH had exit code $EXIT_CODE. Could not ssh to $SSH_HOST" 3
        fi
    fi

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 7A: send to host
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    rsync -zaPr -q --timeout=$RSYNC_TIMEOUT ${LOCAL_PATH} ${SSH_HOST}:$HOST_PATH &>/dev/null
    EXIT_CODE=$?
    if [ ! $EXIT_CODE ]; then
        if [ $EXIT_CODE = 30 ]; then
            echo $txtylw"      warning: rsync timed out after $RSYNC_TIMEOUT. Continuing..."$txtrst
        else
            vexit "rsync -zaPr -q --timeout=120 ${LOCAL_PATH} ${SSH_HOST}:$HOST_PATH had exit code $? \n Could not ssh to $SSH_HOST" 3
        fi
    else
        vecho "rsync success" 1
    fi
else
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Part 6B: Delete file/dir on host
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Hard-coded checks to make sure we don't delete anything important we shouldn't
    vecho "deleting $HOST_PATH on host" 2
    if [[ $HOST_PATH == "" ]]; then
        vexit "HOST_PATH is empty. This is a bug" 3
    fi
    if [[ $HOST_PATH == "/" ]]; then
        vexit "HOST_PATH is /. This is a bug" 3
    fi
    if [[ $HOST_PATH != "/home/monte/carlo_dir/"* && $HOST_PATH != "/home/yodacora/monte-moos/"* ]]; then
        vexit "HOST_PATH is $HOST_PATH. This is a bug" 3
    fi

    # Delete file/dir on host
    ssh -n ${SSH_HOST} "rm -rf $HOST_PATH" &>/dev/null

    # Check exit code
    EXIT_CODE=$?
    if [ ! $EXIT_CODE -eq "0" ]; then
        if [ $EXIT_CODE -eq 255 ]; then
            echo $txtylw"      warning: ssh unable to connect. Continuing..."$txtrst
        else
            vexit "ssh -n ${SSH_HOST} \"rm -rf $HOST_PATH\" had exit code $EXIT_CODE. Could not ssh to $SSH_HOST" 3
        fi
    fi
fi

#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Part 7: Kill the temporary ssh-agent
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
kill -9 $SSH_AGENT_PID
