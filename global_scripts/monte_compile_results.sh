#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 07/13/2023
# Script: monte_compile_results.sh
#--------------------------------------------------------------
# Part 0: Convenience functions, defaults
#--------------------------------------------------------------
ME="monte_compile_results.sh"
TYPE="cp" # cp for copy, ln for link
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"

if [[ $MONTE_MOOS_HOST == "$MYNAME" ]]; then
    OUTPUT_BASE_DIR="${MONTE_MOOS_HOST_WEB_ROOT_DIR}/results"
else
    OUTPUT_BASE_DIR="${CARLO_DIR_LOCATION}/compiled_results"
fi

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS] --job_file=path/to/job_file                           "
        echo "                                                          "
        echo "Updates compiles the results for a single job file given the "
        echo "directory for that job's results and the job file itself. "
        echo "                                                          "
        echo "This script copies files in job_results/web, and appends the    "
        echo "job_results/results.csv file to web/monte/.../job_name/results.csv"
        echo "It also generates a scatterplot of X vs Y and publishes it online."
        echo "   For now, X=<first column in results.csv> Y=<second column>"
        echo "   such that one point is generated per row in results.csv"
        echo ""
        echo "Options:                                              "
        echo "  --help, -h                                         "
        echo "    Display this help message.                        "
        echo "  --job_file=                                         "
        echo "    The job file to be referenced."
        echo "  --input_results=                                   "
        echo "    Directory containing subdirectories for the results"
        echo "    from each run.                                     "
        echo "  --output_results=                                  "
        echo "    Where to put the compiled results on this computer."
        echo ""
        echo "  --verbose=num, -v=num                              "
        echo "    Set verbosity                               "
        echo "  --verbose, -v                                      "
        echo "    Set verbosity to 1                               "
        exit 0
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
        VERBOSE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--input_results="* ]]; then
        INPUT_JOB_RESULTS_DIR="${ARGI#*=}"
    elif [[ "${ARGI}" == "--output_results="* ]]; then
        compiled="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        PATH_TO_JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
        VERBOSE=1
    else
        if [[ -z $PATH_TO_JOB_FILE ]]; then
            PATH_TO_JOB_FILE="$ARGI"
        else
            vexit "Job file $PATH_TO_JOB_FILE already set, so unknown argument: $ARGI" 1
        fi
    fi
done

#--------------------------------------------------------------
#  Part 2.1: Set defaults, check variables
#--------------------------------------------------------------
if [[ -z $PATH_TO_JOB_FILE ]]; then
    vexit "No job file given. Please specify a job file with --job_file=.temp_job_dirs/.../job_file" 2
fi
JOB_NAME=$(job_filename "$PATH_TO_JOB_FILE") # The name of the job_file itself
job_dir=$(job_dirname "$PATH_TO_JOB_FILE")
JOB_SHORT_PATH=$(job_path "$PATH_TO_JOB_FILE")

# Set default input results directory
if [[ -z $INPUT_JOB_RESULTS_DIR ]]; then
    if [[ -d "${CARLO_DIR_LOCATION}/results/$JOB_SHORT_PATH/$JOB_NAME" ]]; then
        INPUT_JOB_RESULTS_DIR="${CARLO_DIR_LOCATION}/results/$JOB_SHORT_PATH"
    else
        vexit "No input results directory given or found at: ${CARLO_DIR_LOCATION}/results/$JOB_SHORT_PATH or ${CARLO_DIR_LOCATION}/results/misc_jobs/$JOB_NAME. Please specify a directory with --input_results=" 2
    fi
fi

# Ensure input results directory exists
if [[ ! -d $INPUT_JOB_RESULTS_DIR ]]; then
    vexit "Input results directory $INPUT_JOB_RESULTS_DIR not found" 2
fi

if [[ -z $compiled ]]; then
    compiled="$OUTPUT_BASE_DIR"/"$JOB_SHORT_PATH"
fi

#--------------------------------------------------------------
#  Part 2.5: Clarify naming conventions
#--------------------------------------------------------------

post_processed_dirs="$compiled/post_processed" # Within the compiled results, where to put the post_processed results
compiled_csv="$compiled/results.csv"
compiled_plot="$compiled/plot"

vecho "PATH_TO_JOB_FILE = $PATH_TO_JOB_FILE" 2
vecho "INPUT_JOB_RESULTS_DIR= $INPUT_JOB_RESULTS_DIR" 2
vecho "JOB_NAME = $JOB_NAME" 2
vecho "JOB_DIR = $job_dir" 2
vecho "COMPILED = $compiled" 2
echo "$txtgry        Output file: $compiled_csv${txtrst}"

#--------------------------------------------------------------
#  Part 3: Extract the results.csv file from each run of the
#          job, merge into one results.csv file.
#  Note: python is used to merge the results.csv files
#--------------------------------------------------------------
# Check that the job has results
if [ ! -d "$INPUT_JOB_RESULTS_DIR" ]; then
    vexit "job results directory $INPUT_JOB_RESULTS_DIR not found" 3
fi

mkdir -p "$compiled"
vecho "monte_merge_results.py --job=$JOB_NAME --output=$compiled_csv  --wd=$INPUT_JOB_RESULTS_DIR" 1
monte_merge_results.py --job="$JOB_NAME" --output="$compiled_csv" --wd="$INPUT_JOB_RESULTS_DIR" #&> /dev/null
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] || echo "${txtylw}Error running scripts/merge_results.py ---job=$JOB_NAME --output=$compiled_csv --wd=$INPUT_JOB_RESULTS_DIR ${txtrst}"

#--------------------------------------------------------------
#  Part 4: Copy the web subdirectories (only for host)
#--------------------------------------------------------------
# Loop through every run of the job
# if [[ $MONTE_MOOS_HOST == $MYNAME ]]; then
for job_result in "$INPUT_JOB_RESULTS_DIR"/*; do
    if [ -d "$job_result" ]; then
        JOB_ID="${job_result#"$INPUT_JOB_RESULTS_DIR"/}" # JOB_ID format: job_name_hash

        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # Check if the job has already been extracted
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if [ -d "$post_processed_dirs/$JOB_ID" ]; then
            vecho "    $job_result has already been extracted. Skipping..." 5
            continue
        fi
        vecho "    $job_result directory has not been extracted. Extracting..." 1

        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # copy the yco/.../job_name/job_name_hash/web/ directory to
        #          /web/results/job_name/post_processed/job_name_hash
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        #  if [ there's something to cp] and [the job hasn't been copied yet]
        if [ -d "$job_result/web" ] && [ ! -d "$post_processed_dirs/$JOB_ID" ]; then
            # only copy if the web isn't empty
            if [ "$(ls -A "$job_result"/web)" ]; then
                mkdir -p "$post_processed_dirs/$JOB_ID"
                # Copy or link the results to the web directory
                if [ "$TYPE" = "cp" ]; then
                    vecho "cp -rp $job_result/web/* $post_processed_dirs/$JOB_ID" 3
                    cp -rp "$job_result/web/"* "$post_processed_dirs/$JOB_ID" 2>/dev/null
                elif [ "$TYPE" = "ln" ]; then
                    vecho "ln -s $job_result/web/* $post_processed_dirs/$JOB_ID" 3
                    ln -s "$job_result/web/"* "$post_processed_dirs/$JOB_ID"
                fi
            else
                vecho "$job_result/web is empty. Nothing to copy" 3
            fi
        else
            [ -d "$job_result/web" ] || { vecho "No results to copy to web (no dir at $job_result/web)" 3; }
            [ ! -d "$post_processed_dirs/$JOB_ID" ] || { vecho "Results have already been copied to ($post_processed_dirs/$JOB_ID)" 3; }
        fi
    else
        vecho "    $job_result is not a directory. Skipping..." 2
    fi
done
# fi

#--------------------------------------------------------------
#  Part 5: Determine what to plot using job file
#--------------------------------------------------------------

if [[ ! -f "$PATH_TO_JOB_FILE" ]]; then
    vexit "Job file ($PATH_TO_JOB_FILE) not found" 12
fi

vecho "Sourcing job file $PATH_TO_JOB_FILE ..." 2
. "${PATH_TO_JOB_FILE}" # source the job file to get information on how to plot
vecho "Sourced job file!" 2
if [[ -z $PLOT_X ]] || [[ -z $PLOT_Y ]]; then
    vecho "PLOT_X or PLOT_Y have not been set in the job file $PATH_TO_JOB_FILE. Not plotting" 1
else
    if [ -f "${compiled_csv}" ]; then
        vecho " plotting: /${MONTE_MOOS_BASE_DIR}/scripts/pltcsv.py $compiled_csv --fname=$compiled_plot --title=$JOB_NAME -x=\"$PLOT_X\" -y=\"$PLOT_Y\"" 2
        /"${MONTE_MOOS_BASE_DIR}"/scripts/pltcsv.py "$compiled_csv" --fname="$compiled_plot" --title="$JOB_NAME" -x="$PLOT_X" -y="$PLOT_Y"
        EXIT_CODE=$?
        [ $EXIT_CODE -eq 0 ] || echo "${txtylw}Error running /${MONTE_MOOS_BASE_DIR}/scripts/pltcsv.py${txtrst}" #$txtylw $txtrst
    else
        vecho "$JOB_NAME has no results yet. Not plotting..." 1
    fi
fi

exit 0
