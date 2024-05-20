#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 12/01/2023
# Script: consolidate_queue.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="consolidate_queue.sh"
OUTPUT_FILENAME="consolidated_queue.txt"
rm -f $OUTPUT_FILENAME # Delete default output file if it exists

source /${MONTE_MOOS_BASE_DIR}/lib/lib_util_functions.sh
INPUT_FILE=""
RUNS_DES_MERGE_TYPE="add"
WHICH_JOBS="all"
BREAKPOINT_STRING="-------BREAKPOINT-------"

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] file.txt                               "
        echo "                                                      "
        echo "This script takes in a queue and merges duplicates    "
        echo "according to a set of rules.                          "
        echo "                                                      "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --output=, -o=                                      "
        echo "    Output file name                                  "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        echo "                                                      "
        echo "  How to handle the breakpoint:                       "
        echo "  --breakpoint=, -b=                                  "
        echo "    Set breakpoint string, aka: only accept job_files "
        echo "    above the line containing this string. Default is:"
        echo "    $BREAKPOINT_STRING          "
        echo "  --ignore_breakpoint, -ib                            "
        echo "    Ignore the breakpoint string.                     "
        echo "                                                      "
        echo "  How to handle the desired/actual runs:              "
        echo "  --max_desired, -md, or --max_actual, -ma            "
        echo "    When comparing runs, take the max                 "
        echo "    of the two. Default is to add them together.      "
        echo "  --add_desired, -ad or --add_actual, -aa             "
        echo "    When comparing runs, take the sum                 "
        echo "    of the two. Default.                              "
        echo "  --first_desired, -fd or --first_actual, -fa         "
        echo "    When comparing runs, take the first               "
        echo "    of the two. Default is to add them together.      "
        echo "  --last_desired, -ld or --last_actual, -la           "
        echo "    When comparing runs, take the last                "
        echo "    of the two. Default is to add them together.      "
        exit 0
    elif [[ "${ARGI}" = "--output="* || "${ARGI}" = "-o="* ]]; then
        OUTPUT_FILENAME="${ARGI#*=}"
    elif [[ "${ARGI}" = "--verbose"* || "${ARGI}" = "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi

    # Breakpoint args
    elif [[ "${ARGI}" = "--breakpoint="* || "${ARGI}" = "-b="* ]]; then
        BREAKPOINT_STRING="${ARGI#*=}"
    elif [[ "${ARGI}" = "--ignore_breakpoint" || "${ARGI}" = "-ib" ]]; then
        ignore_breakpoint="yes"

    # Desired runs args
    elif [[ "${ARGI}" = "--max_desired" || "${ARGI}" = "-md" ]]; then
        RUNS_DES_MERGE_TYPE="max"
    elif [[ "${ARGI}" = "--add_desired" || "${ARGI}" = "-ad" ]]; then
        RUNS_DES_MERGE_TYPE="add"
    elif [[ "${ARGI}" = "--first_desired" || "${ARGI}" = "-fd" ]]; then
        RUNS_DES_MERGE_TYPE="first"
    elif [[ "${ARGI}" = "--last_desired" || "${ARGI}" = "-ld" ]]; then
        RUNS_DES_MERGE_TYPE="last"


    # Only take jobs from before the breakpoint
    elif [[ "${ARGI}" = "--first_jobs" || "${ARGI}" = "-fj" ]]; then
        WHICH_JOBS="first"

    # Actual runs args
    elif [[ "${ARGI}" = "--max_actual" || "${ARGI}" = "-ma" ]]; then
        RUNS_ACT_MERGE_TYPE="max"
    elif [[ "${ARGI}" = "--add_actual" || "${ARGI}" = "-aa" ]]; then
        RUNS_ACT_MERGE_TYPE="add"
    elif [[ "${ARGI}" = "--first_actual" || "${ARGI}" = "-fa" ]]; then
        RUNS_ACT_MERGE_TYPE="first"
    elif [[ "${ARGI}" = "--last_actual" || "${ARGI}" = "-la" ]]; then
        RUNS_ACT_MERGE_TYPE="last"

    # Input file
    else
        if [ -z $INPUT_FILE ]; then
            INPUT_FILE=$ARGI
        else
            vexit "Bad Arg: $ARGI or $INPUT_FILE" 1
        fi
    fi
done


vecho "" 3
vecho "" 3
vecho "RUNS_ACT_MERGE_TYPE=$RUNS_ACT_MERGE_TYPE" 3
vecho "RUNS_DES_MERGE_TYPE=$RUNS_DES_MERGE_TYPE" 3


# Delete the output file if exists
# Before deleting, check that the two files are different
if [[ "$INPUT_FILE" = "$OUTPUT_FILENAME" ]]; then
    vexit "input file cannot equal output file" 2
fi
if [[ -f "$OUTPUT_FILENAME" ]]; then
    vexit "Output file: $OUTPUT_FILENAME exists" 3
fi
mkdir -p "$(dirname $OUTPUT_FILENAME)"
touch "$OUTPUT_FILENAME"

#--------------------------------------------------------------
#  Part 3: Loop through file 1, getting all job names with & args
#--------------------------------------------------------------

job_runs_des=()
job_runs_act=()

# Add newline if not present
[ -n "$(tail -c1 $INPUT_FILE)" ] && printf '\n' >>$INPUT_FILE

line_num=0
while read line; do
    line_num=$((line_num + 1))
    is_comment "$line" && continue

    vecho "Line $line_num= $line" 5

    # Always skip over the breakpoint string
    if [[ "$line" == "$BREAKPOINT_STRING" ]]; then
            if [[ $WHICH_JOBS == "first" ]]; then
                exit 0
            fi
            continue
        # fi
    fi

    # Skip a line if it contains an error
    job_name=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$line" -jf) ; [[ $? -eq 0 ]] || { continue; }
    job_args=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$line" -ja) ; [[ $? -eq 0 ]] || { continue; }
    # job_rd=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$line" -rd) ; [[ $? -eq 0 ]] || { continue; }
    # job_ra=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$line" -ra) ; [[ $? -eq 0 ]] || { continue; }

    # Check if this line has already been added to the output file using grep
    grep -q "$job_name $job_args" $OUTPUT_FILENAME
    if [[ $? -eq 0 ]]; then
        vecho "     This has already been added to queue. Continuing..." 5
        continue
    fi

    # Count the number of runs_desired and runs_actual in both files
    total_rd=0
    total_ra=0

    # next_lines_reached_breakpoint="no"
    # Loop through this file, looking for jobs with the same name and args

    while read remaining_lines; do
        is_comment "$remaining_lines" && continue

        # # Skip breakpoint
        if [[ "$remaining_lines" = "$BREAKPOINT_STRING" ]]; then
            # [[ $ignore_breakpoint != "yes" ]] && { remaining_lines_reached_breakpoint="yes"; }
            vecho "        Reached breakpoint" 5
            continue
        fi

        vecho "" 15
        vecho "        remaining_lines = $remaining_lines" 15

        remaining_lines_job_name=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$remaining_lines" -jf)
        remaining_lines_job_args=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$remaining_lines" -ja)
        
        # If it finds another copy of the line...
        if [[ "$remaining_lines_job_name" == "$job_name" && "$remaining_lines_job_args" == "$job_args" ]]; then
            remaining_lines_job_rd=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$remaining_lines" -rd)
            remaining_lines_job_ra=$(${MONTE_MOOS_BASE_DIR}/scripts/read_queue.sh --line="$remaining_lines" -ra)
            vecho "        Found a match with line $remaining_lines. Currently has rd=$total_rd ra=$total_ra" 5

            # Update number of desired runs
            if [[ "$RUNS_DES_MERGE_TYPE" == "add" ]]; then
                vecho "          Adding $remaining_lines_job_rd to $total_rd" 5
                total_rd=$(($total_rd + $remaining_lines_job_rd))
            elif [[ "$RUNS_DES_MERGE_TYPE" == "max" ]]; then
                if [[ "$remaining_lines_job_rd" -gt "$total_rd" ]]; then
                    vecho "          Replacing total_rd with $remaining_lines_job_rd" 5
                    total_rd=$remaining_lines_job_rd
                fi
            elif [[ "$RUNS_DES_MERGE_TYPE" == "first" ]]; then
                if [[ "$total_rd" -eq "0" ]]; then
                    vecho "          Setting total_rd to $remaining_lines_job_rd" 5
                    total_rd=$remaining_lines_job_rd
                fi
            elif [[ "$RUNS_DES_MERGE_TYPE" == "last" ]]; then
                vecho "          Setting total_rd to $remaining_lines_job_rd" 5
                total_rd=$remaining_lines_job_rd
            fi

            # Update number of actual runs
            if [[ "$RUNS_ACT_MERGE_TYPE" == "add" ]]; then
                vecho "          Adding $remaining_lines_job_ra to $total_ra" 5
                total_ra=$(($total_ra + $remaining_lines_job_ra))
            elif [[ "$RUNS_ACT_MERGE_TYPE" == "max" ]]; then
                if [[ "$remaining_lines_job_ra" -gt "$total_ra" ]]; then
                    vecho "          Replacing total_ra with $remaining_lines_job_ra" 5
                    total_ra=$remaining_lines_job_ra
                fi
            elif [[ "$RUNS_ACT_MERGE_TYPE" == "first" ]]; then
                if [[ "$total_ra" -eq "0" ]]; then
                    vecho "          Setting total_ra to $remaining_lines_job_ra" 5
                    total_ra=$remaining_lines_job_ra
                fi
            elif [[ "$RUNS_ACT_MERGE_TYPE" == "last" ]]; then
                vecho "          Setting total_ra to $remaining_lines_job_ra" 5
                total_ra=$remaining_lines_job_ra
            fi

        else
            vecho "   NOT a match!" 15
        fi
    done <$INPUT_FILE

    # Once the client's runs reach runs_desired, it will remove the line
    # from the file. That way, if the host increases the number of desired_runs,
    # the number of completed_runs will get reset and
    # the host will add it back to the client's queue
    if [[ $total_rd -gt $total_ra ]]; then
        output_line="$job_name $job_args $total_rd $total_ra"
        vecho "output_line = $output_line" 2
        echo "$output_line" >>"$OUTPUT_FILENAME"
    else
        vecho "not adding $job_name $job_args since runs_desired $total_rd=$total_ra runs_act" 2
    fi

done <$INPUT_FILE

