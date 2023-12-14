#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/30/2023
# Script: list_bad_job.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
JOB=""
DELETE=""
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$1" ]]; then echo ${txtgry}"$ME: $2" ${txtrst}; fi }
wecho() { echo ${txtylw}"$ME: $1" ${txtrst}; }
vexit() { echo ${txtred}"$ME: Error $2. Exit Code $2" ${txtrst} ; exit "$1" ; }

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]   [JOB]"
        echo "Lists a job as a bad_job"
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --delete, -d                                        "
        echo "    delete the bad_jobs.txt file on the host          "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" = "--delete" || "${ARGI}" = "-d" ]]; then
        DELETE="yes"
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        if [ -z $JOB ]; then
            JOB="$ARGI"
        else
            vexit "Bad Arg: $ARGI" 1
        fi
    fi
done





#--------------------------------------------------------------
#  Part 3: Get name of the client
#--------------------------------------------------------------
if [ -f "/home/student2680/pablo-common/bin/get_vname.sh" ]; then
    name="$(/home/student2680/pablo-common/bin/get_vname.sh)"
else
    name="$(hostname)"
fi
echo "$name" >myname.txt


#--------------------------------------------------------------
#  Part 4: Write to bad_jobs.txt
#--------------------------------------------------------------
if [[ "${DELETE}" != "yes" ]]; then
  echo "$JOB" >> bad_jobs.txt
else
  rm bad_jobs.txt
  vecho 1 "Delete bad_jobs.txt file"
fi

#--------------------------------------------------------------
#  Part 5: Start ssh agent, create dir
#--------------------------------------------------------------
# Start ssh-agent
eval $(ssh-agent -s) &>/dev/null
ps -p $SSH_AGENT_PID &>/dev/null
SSH_AGENT_RUNNING=$?
[ ${SSH_AGENT_RUNNING} -eq 0 ] || { vecho "Unable to start ssh-agent" 3; }
ssh-add -t 7200 ~/.ssh/id_rsa_yco 2>/dev/null
[ "$?" -eq "0" ] || { vexit "ssh agent unable to add yco key" 3; }
ssh -n "yodacora@oceanai.mit.edu" "mkdir -p ~/monte-moos/clients/bad_jobs" &>/dev/null
EXIT_CODE=$?
if [ ! $EXIT_CODE -eq "0" ]; then
    if [ $EXIT_CODE -eq 255 ]; then
        vecho "$txtylw Warning: ssh unable to connect. Continuing..."$txtrst 0
    fi
fi


#--------------------------------------------------------------
#  Part 6: Write to host or delete the file from the host
#--------------------------------------------------------------
if [[ "${DELETE}" = "yes" ]]; then
    ssh -n "yodacora@oceanai.mit.edu" "rm -f ~/monte-moos/clients/bad_jobs/${name}.txt" &>/dev/null
else
    rsync -zaPr -q bad_jobs.txt "yodacora@oceanai.mit.edu:~/monte-moos/clients/bad_jobs/${name}.txt" # &>/dev/null
fi
# Check exit code for errors
EXIT_CODE=$?
if [ ! $EXIT_CODE -eq "0" ]; then
    if [ $EXIT_CODE -eq 255 ]; then
        vecho "$txtylw Warning: ssh unable to connect. Continuing..."$txtrst 0
    fi
fi



