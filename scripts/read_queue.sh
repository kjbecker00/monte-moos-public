#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 11/21/2023
# Script: read_queue.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
TO_RETURN=""
LINE_NUM=0
QUEUE_FILE="host_job_queue.txt"
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
wecho() { echo ${txtylw}"$ME: $2" ${txtrst}; }
vexit() {
    echo ${txtred}"$ME: Error $1. Exit Code $2" ${txtrst}
    exit "$2"
}

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] -qf=queue_file [NUMBER]                    "
        echo "Returns a desired value from the NUMBERth line of the queue. "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --queue_file=, -qf=                                          "
        echo "    Set which\ file to read (default: host_job_queue.txt)"
        echo "  --line=, -l=                                          "
        echo "    Provide the line itself as an argument instead of a number"
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo "  --job_file, -jf                                     "
        echo "    Return the job file "
        echo "    (ex: kevin00/tutorials/alhpa_tutorial)            "
        echo "  --job_args, -ja                                     "
        echo "    Return the job args "
        echo "  --runs_des, -rd                                     "
        echo "    Return the desired number of runs "
        echo "  --runs_act, -ra                                     "
        echo "    Return the actuail number of runs "
        exit 0
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" = "--queue_file="* || "${ARGI}" = "-qf="* ]]; then
        QUEUE_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" = "--job_file" || "${ARGI}" = "-jf" ]]; then
        TO_RETURN="job_file"
    elif [[ "${ARGI}" = "--job_args" || "${ARGI}" = "-ja" ]]; then
        TO_RETURN="job_args"
    elif [[ "${ARGI}" = "--runs_des" || "${ARGI}" = "-rd" ]]; then
        TO_RETURN="runs_des"
    elif [[ "${ARGI}" = "--runs_act" || "${ARGI}" = "-ra" ]]; then
        TO_RETURN="runs_act"
    elif [[ "${ARGI}" = "--line="* || "${ARGI}" = "-l="* ]]; then
        line="${ARGI#*=}"
    else
        if [[ "$LINE_NUM" -eq 0 ]]; then
            LINE_NUM="${ARGI}"
        else
            vexit "Bad Arg: $ARGI" 1
        fi
    fi
done

#--------------------------------------------------------------
#  Part 3: Error handling
#--------------------------------------------------------------

if [[ "$TO_RETURN" == "" ]]; then
    vexit "No return value specified" 1
fi
if [[ "$line" == "" ]]; then
    if [[ ! -f $QUEUE_FILE ]]; then
        vexit "$QUEUE_FILE not found" 1
    fi
    if [[ "$LINE_NUM" == "" ]]; then
        vexit "No line number or line specified" 1
    fi
    if [[ $LINE_NUM -lt 1 ]]; then
        vexit "Line number must be greater than 0" 1
    fi
fi

#--------------------------------------------------------------
#  Part 4: Read line
#--------------------------------------------------------------
[[ "$line" == "" ]] && { line=$(awk "NR==$LINE_NUM" $QUEUE_FILE); }
[[ "$line" != "" ]] || { vexit "No line found" 1; }

[[ $line != \#* ]] || {
    vecho "Line is a comment..." 5
    exit 2
}
[[ $line != "" ]] || {
    vecho "Skipping empty line..." 5
    exit 2
}

read -ra linearray <<<"$line"

JOB_FILE=${linearray[0]}
JOB_ARGS=""
RUNS_DES=""
RUNS_ACT="0"
for j in "${linearray[@]}"; do
    if [[ "$j" == "$JOB_FILE" ]]; then
        continue
    elif [[ "$j" == "--"* ]]; then
        if [[ ! $JOB_ARGS == "" ]]; then
            JOB_ARGS="${JOB_ARGS} ${j}"
        else
            JOB_ARGS="${j}"
        fi
    elif [[ $RUNS_DES == "" ]]; then
        RUNS_DES=$j
    else
        RUNS_ACT=$j
    fi
done


#--------------------------------------------------------------
#  Part 5: Return values
#--------------------------------------------------------------

# Check for errors
# Checks that RUN_DES and RUN_ACT are integers > 0
[[ "${RUNS_DES//[^0-9]/}" = "$RUNS_DES" ]] || { exit 2 ; }
[[ "${RUNS_ACT//[^0-9]/}" = "$RUNS_ACT" ]] || { exit 2 ; }

if [[ $TO_RETURN = "job_file" ]]; then
    echo "$JOB_FILE"
elif [[ "$TO_RETURN" == "job_args" ]]; then
    echo "$JOB_ARGS"
elif [[ "$TO_RETURN" == "runs_des" ]]; then
    echo "$RUNS_DES"
elif [[ "$TO_RETURN" == "runs_act" ]]; then
    echo "$RUNS_ACT"
else
    vexit "Bad return value specified" 1
fi
