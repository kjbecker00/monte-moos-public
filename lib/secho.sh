#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/08/2023
# Script: secho.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="secho.sh"
TO_PRINT=""
LINES_TO_KEEP=500
HOSTLESS="no"
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_vars.sh"

# Making these seperate from lib_scripts.sh since lib_scripts.sh references this file
vecho() { if [[ "$VERBOSE" -ge "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi; }
vexit() {
    echo "${txtred}""$ME: Error $2. Exit Code $2" "${txtrst}"
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
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo "  --hostless, -nh Without sending to host              "
        exit 0
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" == "--hostless" || "${ARGI}" == "-nh" ]]; then
        HOSTLESS="yes"
    else
        if [ -z "$TO_PRINT" ]; then
            TO_PRINT="$ARGI"
        else
            vexit "Bad Arg: $ARGI" 1
        fi
    fi
done

#--------------------------------------------------------------
#  Part 3: Add other info
#--------------------------------------------------------------
# Temp and free memory (if PI)
if [ -f /usr/bin/vcgencmd ]; then
    TEMP=$(sudo /usr/bin/vcgencmd measure_temp)
    free_memory=$(free -m | awk '/^Mem:/{print $4}')
    TO_PRINT="$TO_PRINT (temp = $TEMP free memory=$free_memory)"
fi
# Number of processes running
TO_PRINT="$TO_PRINT (processes: $(ps aux | wc -l))"

#--------------------------------------------------------------
#  Part 4: Print and write to status.txt
#--------------------------------------------------------------

echo "$TO_PRINT"

TO_ADD="$TO_PRINT ($(date))"
if [ -f "${CARLO_DIR_LOCATION}/status.txt" ]; then
    KEPT_LINES=$(head -n $LINES_TO_KEEP "${CARLO_DIR_LOCATION}/status.txt")
    new_subline="${TO_ADD%%(*}" # remove everything after the first (

    # Remove the most recent line if it is almost the same as the new line. Just update the time
    recent_line=$(head -n 1 "${CARLO_DIR_LOCATION}/status.txt")
    recent_subline="${recent_line%%(*}" # remove everything after the first (

    recent_line2=$(head -n 2 "${CARLO_DIR_LOCATION}/status.txt" | tail -n 1)
    recent_subline2="${recent_line2%%(*}" # remove everything after the first (

    recent_line3=$(head -n 3 "${CARLO_DIR_LOCATION}/status.txt" | tail -n 1)
    recent_subline3="${recent_line3%%(*}" # remove everything after the first (
    
    vecho "New subline: $new_subline" 5
    vecho "Recent subline: $recent_subline" 5
    vecho "Recent subline2: $recent_subline2" 5
    vecho "Recent subline3: $recent_subline3" 5

    if [[ ( $new_subline == "$recent_subline2" && $recent_subline == "$recent_subline3" ) && ${#recent_subline} -ge ${#recent_subline3} ]]; then
        vecho "New line Same as 2nd to last line, last line same as 3rd to last line. Removing last 2 lines..." 5
        # If the last line is the same as the new line, then we replace it
        KEPT_LINES=$(tail -n +3 "${CARLO_DIR_LOCATION}/status.txt")
    elif [[ $new_subline == "$recent_subline" ]]; then
        # If the last line is the same as the new line, then we replace it
        vecho "Same as last line. Removing last line..." 1
        KEPT_LINES=$(tail -n +2 "${CARLO_DIR_LOCATION}/status.txt")
    else
        vecho "Not the same as last line. Keeping last line..." 2
        echo "$TO_ADD" >>status.tmp
    fi
else
    KEPT_LINES=""
fi

echo "$TO_ADD" >status.tmp
echo "$KEPT_LINES" >>status.tmp
mv status.tmp "${CARLO_DIR_LOCATION}"/status.txt

#--------------------------------------------------------------
#  Part 5: Copy to host
#--------------------------------------------------------------

if [[ $MYNAME != "$MONTE_MOOS_HOST" && $HOSTLESS != "yes" ]]; then
    "${MONTE_MOOS_BASE_DIR}/scripts/send2host.sh" "${CARLO_DIR_LOCATION}/status.txt" "${MONTE_MOOS_HOST_RECIEVE_DIR}/clients/status/${MYNAME}.txt" >&/dev/null
fi
