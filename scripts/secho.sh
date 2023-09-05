#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/08/2023
# Script: secho.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
TO_PRINT=""
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$1" ]]; then echo ${txtgry}"$ME: $2" ${txtrst}; fi; }
wecho() { echo ${txtylw}"$ME: $1" ${txtrst}; }
vexit() {
    echo ${txtred}"$ME: Error $2. Exit Code $2" ${txtrst}
    exit "$1"
}

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]                                       "
        echo "Echo to status and out"
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" =~ "--verbose=" || "${ARGI}" =~ "-v=" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        if [ -z $TO_PRINT ]; then
            TO_PRINT="$ARGI"
        else
            vexit "Bad Arg: $ARGI" 1
        fi
    fi
done


#--------------------------------------------------------------
#  Part 3: Add temperature (if PI)
#--------------------------------------------------------------
if [ -f /usr/bin/vcgencmd ]; then
   TEMP=$(sudo /usr/bin/vcgencmd measure_temp)
   free_memory=$(free -m | awk '/^Mem:/{print $4}')
#    TEMP=$(echo "${TEMP}" | awk -F "[=']" '{print($2 * 1.8)+32}')
   TO_PRINT="$TO_PRINT (temp = $TEMP free memory=$free_memory)"
fi


#--------------------------------------------------------------
#  Part 4: Get name of the client
#--------------------------------------------------------------
if [ -f "/home/student2680/pablo-common/bin/get_vname.sh" ]; then
    name="$(/home/student2680/pablo-common/bin/get_vname.sh)"
else
    name="$(hostname)"
fi
echo "$name" >myname.txt


#--------------------------------------------------------------
#  Part 5: Print and write to status.txt
#--------------------------------------------------------------

echo "$TO_PRINT"
TO_ADD="$TO_PRINT (on ${name} as of $(date))"

echo "$TO_ADD" > status.tmp
head -n 20 status.txt >> status.tmp
mv status.tmp status.txt


#--------------------------------------------------------------
#  Part 6: Copy to host
#--------------------------------------------------------------
# Start ssh-agent
eval $(ssh-agent -s) &>/dev/null
ps -p $SSH_AGENT_PID &>/dev/null
SSH_AGENT_RUNNING=$?
[ ${SSH_AGENT_RUNNING} -eq 0 ] || { vecho "Unable to start ssh-agent" 3; }
ssh-add -t 7200 ~/.ssh/id_rsa_yco 2>/dev/null
[ "$?" -eq "0" ] || { vexit "ssh agent unable to add yco key" 3; }
ssh -n "yodacora@oceanai.mit.edu" "mkdir -p ~/monte-moos/clients/status" &>/dev/null
EXIT_CODE=$?
if [ ! $EXIT_CODE -eq "0" ]; then
    if [ $EXIT_CODE -eq 255 ]; then
        vecho "$txtylw Warning: ssh unable to connect. Continuing..."$txtrst 0
    fi
fi
rsync -zaPr -q status.txt "yodacora@oceanai.mit.edu:~/monte-moos/clients/status/${name}.txt" &>/dev/null
