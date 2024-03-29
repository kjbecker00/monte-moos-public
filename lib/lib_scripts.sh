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
secho() { /${MONTE_MOOS_BASE_DIR}/lib/secho.sh "$1"; } # status echo

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
    input=$1
    this_job_path=$(job_path $input)
    this_job_dir="${this_job_path%%/*}" # extract everything before /
    if [[ -z $this_job_dir  || "$(job_filename $input)" == "$this_job_dir" ]]; then
        this_job_dir=misc_job
    fi
    echo $this_job_dir
}

#--------------------------------------------------------------
# From a queue line, extract the JOB_PATH
#     foo/bar  -> foo/bar
#     foo//bar -> foo/bar
#     /home/job_dirs/foo/bar -> foo/bar
#--------------------------------------------------------------
job_path() { 
    input=$1
    input="${input//\/\//\/}" # Replace // with /
    input="${input//\/\//\/}" # Replace // with / (again)
    echo "${input#*job_dirs/}" # extract everything after job_dirs/
}
