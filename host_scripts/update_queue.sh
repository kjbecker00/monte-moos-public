#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 07/18/2023
# Script: host_scripts/update_queue.sh
#--------------------------------------------------------------
# Part 1: Convenience functions   
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtgry}; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]                                       "
        echo "Updates the queue.txt file, also updates the results  "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" = "foo" || "${ARGI}" = "bar" ]]; then
        FOOBAR=0
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
	     vexit "Bad Arg: $ARGI" 1
    fi
done

#--------------------------------------------------------------
#  Part 3: 
#--------------------------------------------------------------

HOST_RESULTS_DIR="/home/yodacora/monte-moos/results"
ENCRYPTED_QUEUE_FILE="/home/web/monte/clients/host_job_queue.txt.enc"
OUTPUT_BASE_DIR="/home/web/monte/results"
QUEUE_FILE="host_job_queue.txt"
QUEUE_COMPLETE="yes"

# Number of jobs in queue
length=$(wc -l "$QUEUE_FILE" | awk '{print $1}')
for ((i=1; i<=length; i++))
do
    # select ith job from the queue
    line=$(awk -v n=$i 'NR == n {print; exit}' "$QUEUE_FILE")
    if [[ -z $line ]]; then
        vecho "Line was empty. Continuing..." 4
        continue
    fi

    # Skips over commented out lines (start with #)
    if [[ $line == \#* ]]; then
        vecho "Skipping comment..." 4
        continue
    fi

    vecho "Line: $line" 3

    # check number of runs left for that job
    linearray=($line)
    JOB_PATH=${linearray[0]}
    RUNS_DES=${linearray[1]}

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Count number of runs based on the number of subdirectories

    THROWAWAY=$(ls -1 $HOST_RESULTS_DIR/$JOB_PATH/ 2>/dev/null)
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        if [[ $EXIT_CODE -eq 2 ]]; then
            vecho "    $HOST_RESULTS_DIR/$JOB_PATH does not exist. Assuming count is at 0..." 1
        else
            vexit "ls returned exit code: $EXIT_CODE. Check that user has access to $HOST_RESULTS_DIR/$JOB_PATH/" 2
        fi
        RUNS_ACT=0
    else

        vecho "    counting results in $HOST_RESULTS_DIR/"$JOB_PATH"/ " 1
        RUNS_ACT=$(ls -1 $HOST_RESULTS_DIR/"$JOB_PATH"/ 2>/dev/null| wc -l)  
    fi

    if [[ $RUNS_ACT -ge $RUNS_DES ]]; then
        echo $txtgrn"    $JOB_PATH ran $RUNS_ACT out of $RUNS_DES runs. Done! "$txtrst
    else
        echo $txtylw"    $JOB_PATH ran $RUNS_ACT out of $RUNS_DES runs "$txtrst
        QUEUE_COMPLETE="no"
    fi

    if [ "$RUNS_ACT" -gt 0 ]; then

        compiled="$OUTPUT_BASE_DIR/$JOB_PATH" 

        # - - - - - - - - - - - - - - - - - - - -
        # Count using lines in csv
        RESULTS_CSV="$compiled/results.csv"
        if [ -f "$RESULTS_CSV" ]; then
            RUNS_CSV=$(cat "$RESULTS_CSV" | wc -l)
            RUNS_CSV=$((RUNS_CSV-1))
        else
            RUNS_CSV=0
        fi

        # - - - - - - - - - - - - - - - - - - - -
        # Count using subdirectories
        if [ -f "$RUNS_DIRS" ]; then
            RUNS_DIRS=$(find "$compiled" -mindepth 1 -maxdepth 1 -type d | wc -l)
        else   
            RUNS_DIRS=0
        fi

        # - - - - - - - - - - - - - - - - - - - -
        # Should have some compiled results, unsure
        # which method is being used though
        if [ $RUNS_CSV -gt $RUNS_DIRS ]; then
            RUNS_PROCESSED=$RUNS_CSV
        else
            RUNS_PROCESSED=$RUNS_DIRS
        fi

        # - - - - - - - - - - - - - - - - - - - -
        # (Maybe) post-process the results again
        if [ "$RUNS_ACT" -le "$RUNS_PROCESSED" ]; then
            vecho "    $RESULTS_CSV processed $RUNS_PROCESSED out of $RUNS_ACT runs. No need to update results..." 1
        else
            vecho "    $RESULTS_CSV processed $RUNS_PROCESSED out of $RUNS_ACT runs. Updating..." 1
            vecho "running ./host_scripts/update_results.sh $HOST_RESULTS_DIR/$JOB_PATH" 1
            ./host_scripts/update_results.sh "$HOST_RESULTS_DIR/$JOB_PATH"
            EXIT_CODE=$?
            [ $EXIT_CODE -eq 0 ]    || { vexit "running ./host_scripts/update_results.sh returned exit code: $EXIT_CODE" 9; }
        fi
    fi

    # replace the line in queue with the newly counted number of runs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s@^$JOB_PATH.*@$JOB_PATH $RUNS_DES $RUNS_ACT@" "$QUEUE_FILE"
    else
        # Linux
        sed -i'' "s@^$JOB_PATH.*@$JOB_PATH $RUNS_DES $RUNS_ACT@" "$QUEUE_FILE"
    fi


done


# Re-encrypt the file
vecho "Encrypting $QUEUE_FILE" 2
cp "$QUEUE_FILE" "backup_$QUEUE_FILE" || exit 3
./encrypt_file.sh $QUEUE_FILE > /dev/null
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ]    || { vexit "running ./encrypt_file.sh returned exit code: $EXIT_CODE" 9; }
mv "$QUEUE_FILE.enc" "$ENCRYPTED_QUEUE_FILE"
mv "backup_$QUEUE_FILE" "$QUEUE_FILE"


if [ $QUEUE_COMPLETE == "yes" ]; then
    echo  "$(tput bold)$txtgrn    Queue complete! $txtrst"
    exit 0
else
    echo  "$txtylw    Queue not complete. $txtrst"
    exit 1
fi


