#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 12/01/2023
# Script: merge_queues.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
OUTPUT_FILENAME="merged_queue.txt"
rm -f $OUTPUT_FILENAME    # Delete default output file if it exists
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi }
wecho() { echo ${txtylw}"$ME: $1" ${txtrst}; }
vexit() { echo ${txtred}"$ME: Error $2. Exit Code $2" ${txtrst} ; exit "$1" ; }
INPUT_FILE=""
RUNS_DES_MERGE_TYPE="add"

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] file.txt                    "
        echo "This script takes in a queue and merges duplicates."
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --output=, -o=                                          "
        echo "    Output file name                         "
        echo "  --max_desired, -md                                  "
        echo "    When comparing desired runs, take the max         "
        echo "    of the two. Default is to add them together.      "
        echo "  --add_desired, -ad                                  "
        echo "    When comparing desired runs, take the sum         "
        echo "    of the two. Default.      "
        echo "  --first_desired, -fd                                  "
        echo "    When comparing desired runs, take the first        "
        echo "    of the two. Default is to add them together.      "
        echo "  --last_desired, -ld                                  "
        echo "    When comparing desired runs, take the last        "
        echo "    of the two. Default is to add them together.      "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" = "--max_desired" || "${ARGI}" = "-md" ]]; then
        RUNS_DES_MERGE_TYPE="max"
    elif [[ "${ARGI}" = "--first_desired" || "${ARGI}" = "-fd" ]]; then
        RUNS_DES_MERGE_TYPE="first"
    elif [[ "${ARGI}" = "--last_desired" || "${ARGI}" = "-ld" ]]; then
        RUNS_DES_MERGE_TYPE="last"
    elif [[ "${ARGI}" = "--add_desired" || "${ARGI}" = "-ad" ]]; then
        RUNS_DES_MERGE_TYPE="add"
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    elif [[ "${ARGI}" = "--output="* || "${ARGI}" = "-o="* ]]; then
        OUTPUT_FILENAME="${ARGI#*=}"
    else
        if [ -z $INPUT_FILE ]; then
            INPUT_FILE=$ARGI
        else
	        vexit "Bad Arg: $ARGI" 1
        fi
    fi
done

# Check if output_filename exists already. But delete default output file if it exists
rm -f "merged_queue.txt"
if [ -f "$OUTPUT_FILENAME" ]; then
    vexit "Output file exists already" 1
fi
touch $OUTPUT_FILENAME


#--------------------------------------------------------------
#  Part 3: Loop through file 1, getting all job names with & args
#--------------------------------------------------------------

job_runs_des=()
job_runs_act=()

# Add newline if not present
[ -n "$(tail -c1 $INPUT_FILE)" ] && printf '\n' >>$INPUT_FILE
while read line; do
    # Skip comments, empty lines
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue


    vecho "Line = $line" 5

    job_name=$(./scripts/read_queue.sh --line="$line" -jf)
    job_args=$(./scripts/read_queue.sh --line="$line" -ja)
    job_rd=$(./scripts/read_queue.sh --line="$line" -rd)
    job_ra=$(./scripts/read_queue.sh --line="$line" -ra)

    vecho "job_name = $job_name" 5
    vecho "job_args = $job_args" 5
    vecho "job_rd = $job_rd" 5 
    vecho "job_ra = $job_ra" 5
    vecho "" 5
    vecho "" 5

    # Check if this line has already been added to the output file using grep
    grep -q "$job_name $job_args" $OUTPUT_FILENAME
    if [[ $? -eq 0 ]]; then
        vecho "     This has already been added to queue. Continuing..." 5
        continue
    fi


    # Count the number of runs_desired and runs_actual in both files
    total_rd=0
    total_ra=0

    # Loop through this file, looking for jobs with the same name and args
    while read next_lines; do
        vecho "" 5
        vecho "   next_lines = $next_lines" 5
        next_lines_job_name=$(./scripts/read_queue.sh --line="$next_lines" -jf)
        next_lines_job_args=$(./scripts/read_queue.sh --line="$next_lines" -ja)
        next_lines_job_rd=$(./scripts/read_queue.sh --line="$next_lines" -rd)
        next_lines_job_ra=$(./scripts/read_queue.sh --line="$next_lines" -ra)

        # If it finds another copy of the file...
        if [[ "$next_lines_job_name" == "$job_name" && "$next_lines_job_args" == "$job_args" ]]; then
            vecho "     Found a match!" 5

            # Update number of desired runs
            if [[ "$RUNS_DES_MERGE_TYPE" == "add" ]]; then
                vecho "     Adding $next_lines_job_rd to $total_rd" 5
                total_rd=$(($total_rd + $next_lines_job_rd))
            elif [[ "$RUNS_DES_MERGE_TYPE" == "max" ]]; then
                if [[ "$next_lines_job_rd" -gt "$total_rd" ]]; then
                    vecho "     Replacing total_rd with $next_lines_job_rd" 5
                    total_rd=$next_lines_job_rd
                fi
            elif [[ "$RUNS_DES_MERGE_TYPE" == "first" ]]; then
                if [[ "$total_rd" -eq "0" ]]; then
                    vecho "     Setting total_rd to $next_lines_job_rd" 5
                    total_rd=$next_lines_job_rd
                fi
            elif [[ "$RUNS_DES_MERGE_TYPE" == "last" ]]; then
                vecho "     Setting total_rd to $next_lines_job_rd" 5
                total_rd=$next_lines_job_rd
            fi

            # Update number of actual runs
            if [[ $next_lines_job_ra -gt $total_ra ]]; then
                vecho "     Replacing total_ra with $next_lines_job_ra" 5
                total_ra=$next_lines_job_ra
            else
                vecho "     total_ra $total_ra is already greater than $next_lines_job_ra" 5
            fi
        else
            vecho "   NOT a match!" 5
        fi
    done < $INPUT_FILE

    # Once the client's runs reach runs_desired, it will remove the line
    # from the file. That way, if the host increases the number of desired_runs,
    # the number of completed_runs will get reset and
    # the host will add it back to the client's queue
    if [[ $total_rd -gt $total_ra ]]; then
        output_line="$job_name $job_args $total_rd $total_ra"
        vecho "output_line = $output_line" 5
        echo "$output_line" >> $OUTPUT_FILENAME
    else
        vecho "not adding $job_name $job_args since runs_desired=runs_act" 5
    fi
    
done < $INPUT_FILE



#--------------------------------------------------------------
#  Part 5: Print out the merged queue
#--------------------------------------------------------------

touch $OUTPUT_FILENAME

for key in "${!job_runs_des[@]}"; do
    echo "$key ${job_runs_des[$key]} ${job_runs_act[$key]}"
done






