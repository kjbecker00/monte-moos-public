#!/bin/bash
#-------------------------------------------------------------- 
# Author: Kevin Becker
# Date: 07/13/2023
# Script: update_results.sh
#-------------------------------------------------------------- 
# Part 1: Convenience functions   
#-------------------------------------------------------------- 
ME=$(basename "$0")
VERBOSE=0
TYPE="cp" # cp for copy, ln for link
txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green 
txtylw=$(tput setaf 3) # Yellow                    
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey                             
# vecho "message" level_int 
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }

JOB_RESULTS=""
OUTPUT_BASE_DIR="/home/web/monte/results"
HOST_RESULTS_DIR="/home/yodacora/monte-moos/results"
BASE_JOB_DIR="job_dirs"
#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do                                                          
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then   
	    echo "$ME: [OPTIONS] job_results                           "
	    echo "Given a directory for the job_results, this script    "
	    echo "Copies files in job_results/web, and appends the    "
	    echo "job_results/results.csv file to web/monte/.../job_name/results.csv"
	    echo "It also generates a scatterplot of X vs Y and publishes it online."
	    echo "   For now, X=<first column in results.csv> Y=<second column>"
	    echo "   such that one point is generated per row in results.csv"
	    echo "Options:                                              "
        echo "  --help, -h                                         "
        echo "    Display this help message                        "
        echo "  --verbose=num, -v=num                                      "
        echo "    Set verbosity                               "
        echo "  --verbose, -v                                      "
        echo "    Set verbosity to 1                               "
 	      exit 0;                                                 
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then 
        VERBOSE="${ARGI#*=}"                                                     
    elif [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then 
        VERBOSE=1                                                     
    else              
        if [ -z $JOB_RESULTS ]; then
            JOB_RESULTS=$ARGI
        else
            vexit "Unknown argument: $ARGI" 1
        fi                    
    fi                                                                  
done 

#-------------------------------------------------------------- 
#  Part 3: Extract the results.csv file from each run of the 
#          job, merge into one results.csv file.
#  Note: python is used to merge the results.csv files
#-------------------------------------------------------------- 
# Check that the job has results
if [ ! -d "$JOB_RESULTS" ]; then
    vexit "job results directory $JOB_RESULTS not found" 3
fi


# Extract the job name (and the hash)
JOB_NAME=$(basename "$JOB_RESULTS")

# Extract the job dir name from the path
# JOB_DIR="$(basename "$(dirname "$JOB_RESULTS")")"
JOB_DIR_FULL=$(dirname ${JOB_RESULTS})
JOB_DIR=${JOB_DIR_FULL#$HOST_RESULTS_DIR/}

# Create the output file if DNE
compiled="$OUTPUT_BASE_DIR/$JOB_DIR/$JOB_NAME" 
post_processed_dirs="$compiled/post_processed"
compiled_csv="$compiled/results.csv"
compiled_plot="$compiled/plot"

echo "$txtgry        Output file: $compiled_csv${txtrst}"

mkdir -p $(dirname $compiled_csv)
vecho " compiled_csv=$compiled_csv" 2


# EXAMPLE OF WHAT EACH VAR MAY LOOK LIKE:
# JOB_NAME=              s1_alpha_job
# JOB_DIR_FULL=          /home/yodacora/monte-moos/results/kevin00/unittest/alpha2
# JOB_DIR=               kevin00/unittest/alpha2
# compiled=              /home/web/monte/results/kevin00/unittest/alpha2/s1_alpha_job
# post_processed_dirs=   /home/web/monte/results/kevin00/unittest/alpha2/s1_alpha_job/post_processed
# compiled_csv=          /home/web/monte/results/kevin00/unittest/alpha2/s1_alpha_job/results.csv
# compiled_plot=         /home/web/monte/results/kevin00/unittest/alpha2/s1_alpha_job/plot

vecho "scripts/merge_results.py --job=$JOB_NAME --output=$compiled_csv  --wd=$JOB_RESULTS" 1
scripts/merge_results.py --job="$JOB_NAME" --output="$compiled_csv"  --wd="$JOB_RESULTS" #&> /dev/null
[ $? -eq 0 ] || echo "${txtylw}Error running scripts/merge_results.py ---job=$JOB_NAME --output=$compiled_csv --wd=$JOB_RESULTS ${txtrst}"


#-------------------------------------------------------------- 
#  Part 4: Copy the web subdirectories
#-------------------------------------------------------------- 
# Loop through every run of the job
for job_result in "$JOB_RESULTS"/*; do
    if [ -d "$job_result" ]; then
        JOB_ID="${job_result#$JOB_RESULTS/}" # JOB_ID format: job_name_hash

        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # Check if the job has already been extracted
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if [ -d "$$post_processed_dirs/$JOB_ID" ]; then
            vecho "    $job_result has already been extracted. Skipping..." 5
            continue
        else
                vecho "    $job_result has not been extracted yet." 3
        fi
        vecho "    $job_result directory has not been extracted. Extracting..." 5
    
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # copy the yco/.../job_name/job_name_hash/web/ directory to 
        #          /web/results/job_name/post_processed/job_name_hash
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        #  if [ there's something to cp] and [the job hasn't been copied yet]
        if [ -d "$job_result/web" ] && [ ! -d "$post_processed_dirs/$JOB_ID" ]; then
          mkdir -p "$post_processed_dirs/$JOB_ID"

          # Copy or link the results to the web directory
          if [ "$TYPE" = "cp" ]; then
            vecho "cp -rp $job_result/web/* $post_processed_dirs/$JOB_ID" 3
            cp -rp "$job_result/web/"* "$post_processed_dirs/$JOB_ID"
          elif [ "$TYPE" = "ln" ]; then
            vecho "ln -s $job_result/web/* $post_processed_dirs/$JOB_ID" 3
            ln -s "$job_result/web/"* "$post_processed_dirs/$JOB_ID"
          fi
        else
          [ -d "$job_result/web" ]  || { vecho "No results to copy to web (no dir at $job_result/web)" 3 ; }
          [ ! -d "$post_processed_dirs/$JOB_ID" ]  || { vecho "Results have already been copied to ($post_processed_dirs/$JOB_ID)" 3 ; }
        fi
    else
        vecho "    $job_result is not a directory. Skipping..." 2
    fi
done




#-------------------------------------------------------------- 
#  Part 4: Determine what to plot using job file
#-------------------------------------------------------------- 

JOB_FILE_FULL="$BASE_JOB_DIR/$JOB_DIR/$JOB_NAME"
if [ -f $JOB_FILE_FULL ]; then
    vecho "Sourcing job file $JOB_FILE_FULL ..." 1
    . "${JOB_FILE_FULL}" # source the job file to get information on how to plot
    vecho "Sourced job file!" 2
    if [[ -z $PLOT_X ]] || [[ -z $PLOT_Y ]]; then
        vecho "PLOT_X or PLOT_Y have not been set in the job file $JOB_FILE_FULL. Not plotting" 1
    else
        vecho " plotting: ./scripts/pltcsv.py $compiled_csv --fname=$compiled_plot --title=$JOB_NAME -x=\"$PLOT_X\" -y=\"$PLOT_Y\"" 1
        ./scripts/pltcsv.py "$compiled_csv" --fname="$compiled_plot" --title="$JOB_NAME" -x="$PLOT_X" -y="$PLOT_Y"
        [ $? -eq 0 ] || echo "${txtylw}Error running ./scripts/pltcsv.py${txtrst}" #$txtylw $txtrst
    fi
else
    vexit "Job file ($JOB_FILE_FULL) not found" 12
fi

