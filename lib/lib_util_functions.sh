#!/bin/bash
# Kevin Becker, May 26 2023
#--------------------------------------------------------------
# Library of utility scripts for monte-moos
#--------------------------------------------------------------

#--------------------------------------------------------------
# Verbose echo
#--------------------------------------------------------------
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }

#--------------------------------------------------------------
# Status echo
#--------------------------------------------------------------
secho() { /"${MONTE_MOOS_BASE_DIR}"/lib/secho.sh "$1"; } # status echo

#--------------------------------------------------------------
# Warning echo
#--------------------------------------------------------------
wecho() { echo ${txtylw}"$ME: $1" ${txtrst}; }

#--------------------------------------------------------------
# Verbose exit
#--------------------------------------------------------------
vexit() {
    secho "${txtred}$ME: Error: $1. Exit Code $2 $txtrst"
    exit "$2"
}

#--------------------------------------------------------------
# Safe exit: restores old PATH and IVP_BEHAVIOR_DIRS
#--------------------------------------------------------------
safe_exit() {
    PATH=$original_path
    IVP_BEHAVIOR_DIRS=$original_ivp_behavior_dirs
    export PATH
    export IVP_BEHAVIOR_DIRS
    if [ $1 -ne 0 ]; then
        echo ""
        echo "${txtred}$ME Exiting safely. Resetting PATH and IVP_BEHAVIOR_DIRS... ${txtrst}"
    fi
    exit $1
}

#--------------------------------------------------------------
# Check for force quit file, quit if exists
#--------------------------------------------------------------
check_quit() { if [ -f "${CARLO_DIR_LOCATION}/force_quit" ]; then
    secho "${CARLO_DIR_LOCATION}/force_quit file found. Exiting"
    exit 0
fi; }

#--------------------------------------------------------------
# Checks for force quit file while sleeping
#--------------------------------------------------------------
check_sleep() { for i in $(seq 1 1 $1); do
    check_quit
    sleep 1
done; }

#--------------------------------------------------------------
# From a queue line, extract the filename of the job
#--------------------------------------------------------------
job_filename() {
    echo "$(basename $1)"
}

#--------------------------------------------------------------
# Extract the JOB_DIR (dir right after job_dirs/. Or, the first
# dir listed, should job_dirs not be given)
#       foo/bar/baz -> foo
#       foo/bar -> foo
#       /home/job_dirs/foo/bar -> foo
#       jobname -> misc_job
#--------------------------------------------------------------
job_dirname() {
    local input
    local this_job_path
    local this_job_dir
    input=$1
    this_job_path=$(job_path "$input")
    this_job_dir="${this_job_path%%/*}" # extract everything before /
    if [[ -z $this_job_dir || "$(job_filename $input)" == "$this_job_dir" ]]; then
        this_job_dir=misc_job
    fi
    echo "$this_job_dir"
}

#--------------------------------------------------------------
# From a queue line, extract the JOB_PATH
#     foo/bar  -> foo/bar
#     foo//bar -> foo/bar
#     /home/job_dirs/foo/bar -> foo/bar
#--------------------------------------------------------------
job_path() {
    local input
    input=$1
    input="${input//\/\//\/}"  # Replace // with /
    input="${input//\/\//\/}"  # Replace // with / (again)
    echo "${input#*job_dirs/}" # extract everything after job_dirs/
}

#--------------------------------------------------------------
# Given a file, add .tmp_ to the filename
#     foo/bar  -> foo/.tmp_bar
#     foo//bar -> foo/.tmp_bar
#     foo/.tmp_bar -> foo/.tmp_tmp_bar
#     /home/job_dirs/foo/bar -> /home/job_dirs/foo/.tmp_bar
# This function produces a deterministic (repeatable) output
#--------------------------------------------------------------
temp_filename() {
    local input
    input=$1
    input="${input//\/\//\/}" # Replace // with /
    input="${input//\/\//\/}" # Replace // with / (again)
    input="${input/.tmp_/tmp_}" # Replace .tmp_ with tmp_
    echo "$(dirname $input)/.tmp_$(basename $input)"
}

#--------------------------------------------------------------
# Given a job and its args determine if its in bad_jobs.txt
#--------------------------------------------------------------
is_bad_job() {
    local JOB_FILE
    local BAD_JOBS_FILE
    JOB_FILE=$1
    BAD_JOBS_FILE="$2"
    if [[ -z $BAD_JOBS_FILE ]]; then
        BAD_JOBS_FILE="${CARLO_DIR_LOCATION}/bad_jobs.txt"
    fi
    if [[ ! -f $BAD_JOBS_FILE ]]; then
        return 1
    fi
    if grep -Fq "$JOB_FILE" "${BAD_JOBS_FILE}"; then
        return 0 # job is in bad_jobs.txt
    fi
    return 1
}

#--------------------------------------------------------------
# Gets the current hour with out a leading 0
#--------------------------------------------------------------
get_hour() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        echo "$(date +%k)"
    else
        # GNU/Linux
        echo "$(date +%-H)"
    fi
}

#--------------------------------------------------------------
# Determines if you should skip over a line
#--------------------------------------------------------------
is_comment() {
    if [[ $1 == "" ]]; then
        vecho "Identified as blank line... $1" 50
        return 0
    fi
    if [[ $1 == \#* ]]; then
        vecho "Identified as comment... $1" 50
        return 0
    fi
    return 1
}
