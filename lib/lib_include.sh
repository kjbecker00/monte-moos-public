#!/bin/bash
# Kevin Becker, May 26 2023
#--------------------------------------------------------------
# Library of standard utility scripts/var initalizations 
# for monte-moos
#--------------------------------------------------------------

# Initialize VERBOSE, tput colors
source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_vars.sh

# Convenience functions (vecho, secho, safe_exit, etc)
source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_util_functions.sh

# Functions for adding repos to PATH and IVP_BEHAVIOR_DIRS
source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_sourcing_utils.sh

