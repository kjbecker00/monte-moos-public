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
