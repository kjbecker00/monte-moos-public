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
LINES_TO_KEEP=500
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi; }
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
        echo "                                                          "
        echo "Status echo. Prints a line to status.txt, push to     "
        echo " the host, and print to screen. Also generates myname.txt"
        echo " if needed. If the most recent secho line is similar to"
        echo " the line to be secho'd, then just the time is updated.    "
        echo " The secho.txt file retains the first $LINES_TO_KEEP lines. "
        echo "                                                          "
        echo "Also generate myname.txt"
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
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
echo "$name" > "${CARLO_DIR_LOCATION}/myname.txt"


#--------------------------------------------------------------
#  Part 5: Print and write to status.txt
#--------------------------------------------------------------

echo "$TO_PRINT"


TO_ADD="$TO_PRINT ($(date))"
if [ -f ${CARLO_DIR_LOCATION}/status.txt ]; then
    KEPT_LINES=$(head -n $LINES_TO_KEEP ${CARLO_DIR_LOCATION}/status.txt)
    # Remove the most recent line if it is almost the same as the new line. Just update the time
    recent_line=$(head -n 1 ${CARLO_DIR_LOCATION}/status.txt)
    recent_subline="${recent_line%%(*}" # remove everything after the first (
    new_subline="${TO_ADD%%(*}" # remove everything after the first (
    if [[ $new_subline == $recent_subline ]]; then
        # If the last line is the same as the new line, then we replace it
        vecho "Same as last line" 1
        KEPT_LINES=$(tail -n +2 ${CARLO_DIR_LOCATION}/status.txt)
    else
        echo "$TO_ADD" >> status.tmp
    fi
else
    KEPT_LINES=""
fi




echo "$TO_ADD" > status.tmp
echo "$KEPT_LINES" >> status.tmp
mv status.tmp ${CARLO_DIR_LOCATION}/status.txt


#--------------------------------------------------------------
#  Part 6: Copy to host
#--------------------------------------------------------------
./scripts/send2host.sh "${CARLO_DIR_LOCATION}/status.txt" "${MONTE_MOOS_HOST_RECIEVE_DIR}/clients/status/${name}.txt" >&/dev/null

