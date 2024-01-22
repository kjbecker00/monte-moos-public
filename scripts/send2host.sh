#!/bin/bash
# Kevin Becker, May 26 2023

# Script used to publish files to the host
ME="send2host.sh"
VERBOSE=0

LOCAL_PATH=""
HOST_PATH=""
SSH_HOST="$MONTE_MOOS_USERNAME@$MONTE_MOOS_HOSTNAME_SSH"

txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green                     
txtylw=$(tput setaf 3) # Yellow                     
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey                     
txtbld=$(tput bold)    # Bold                             
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    echo "ARGI: $ARGI"
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh local_dir host_dir [OPTIONS]"
        echo "                                                          "
        echo " Used to publish files to the host. Essentially a wrapper "
        echo " for rsync. Used by secho.sh, extract_results.sh and others..."
        echo "                                                          "
        echo "Options:                                                   " 
        echo " --help, -h Show this help message                         " 
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
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
if [ -z $LOCAL_PATH ]; then
    vexit "missing local_dir/local_path" 2
fi

if [ -z $HOST_PATH ]; then
    vexit "missing host_path" 2
fi


#-------------------------------------------------------
#  Part 2: Check ssh key
#-------------------------------------------------------

# Check for ssh key
if [ -f $MONTE_MOOS_HOST_SSH_KEY ] ; then    
    chmod -R go-rwx $MONTE_MOOS_HOST_SSH_KEY &> /dev/null
fi


#-------------------------------------------------------
#  Part 3: Start ssh agent
#-------------------------------------------------------
eval `ssh-agent -s` &> /dev/null
ps -p $SSH_AGENT_PID &> /dev/null
SSH_AGENT_RUNNING=$?
if [ ${SSH_AGENT_RUNNING} -ne 0 ] ; then
    vexit "Unable to start ssh-agent" 3
fi


#-------------------------------------------------------
#  Part 4: Add ssh key
#-------------------------------------------------------
ssh-add -t 7200 $MONTE_MOOS_HOST_SSH_KEY 2> /dev/null
EXIT_CODE=$?
if [ "$EXIT_CODE" -ne "0" ] ; then 
    vexit "ssh agent unable to add ssh key" 3
fi


#-------------------------------------------------------
#  Part 5: Make dir on host
#-------------------------------------------------------
echo "${txtgry}      ${LOCAL_PATH}${txtblu} → ${txtbld}${SSH_HOST}:${txtrst}${HOST_PATH}${txtrst}"
if [ -d $LOCAL_PATH ]; then
    DIR_TO_MAKE="$HOST_PATH"
else
    DIR_TO_MAKE="$(dirname $HOST_PATH)"
fi
vecho "making dir $DIR_TO_MAKE on host" 2
ssh -n ${SSH_HOST} "mkdir -p $DIR_TO_MAKE" &> /dev/null
EXIT_CODE=$?
if [ ! $EXIT_CODE -eq "0" ]; then
    if [ $EXIT_CODE -eq 255 ]; then
        echo $txtylw"      warning: ssh unable to connect. Continuing..."$txtrst
    else 
        vexit "ssh -n ${SSH_HOST} mkdir -p $HOST_PATH had exit code $EXIT_CODE. Could not ssh to $SSH_HOST" 3
    fi
fi


#-------------------------------------------------------
#  Part 6: send to host
#-------------------------------------------------------
rsync -zaPr -q --timeout=$RSYNC_TIMEOUT ${LOCAL_PATH} ${SSH_HOST}:$HOST_PATH &> /dev/null
EXIT_CODE=$?
if [ ! $EXIT_CODE ]; then
    if [ $EXIT_CODE = 30 ] ; then
        echo $txtylw"      warning: rsync timed out after $RSYNC_TIMEOUT. Continuing..."$txtrst
    else
        vexit "rsync -zaPr -q --timeout=120 ${LOCAL_PATH} ${SSH_HOST}:$HOST_PATH had exit code $? \n Could not ssh to $SSH_HOST" 3
    fi
else
    vecho "rsync success" 1
fi


