#!/bin/bash
# Kevin Becker, May 26 2023

# Example:
# ./source_launch.sh mylaunch moos-ivp-extend "missions/lab_05/alpha_return" 10
#          runs: ./mylaunch.sh in missions/lab_05/alpha_return with timewarp 10

#-------------------------------------------------------
#  Part 1: Initalize the variables
#-------------------------------------------------------
# Get the directory name and mission dir bname from the first 2 arguments
SCRIPTNAME="launch"
REPO_NAME=""
# BIN_SDIR=""
# LIB_SDIR=""
MISSION_SDIR=""
FLOW_DOWN_ARGS="" # Get the mission name from the third argument
TO_SOURCE="yes"   # if the script should add repo/bin to the path
TO_ADD_LIB="yes"  # if the script should add repo/lib to IVP_BEHAVIOR_DIRS

ME="source_launch.sh"
source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"
trap ctrl_c INT
ctrl_c() {
    safe_exit 130
}

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --script=[SCRIPT_NAME] --repo=[REPO_NAME] --mission=[SUBDIRECTORy] [FLOW_DOWN_ARGS]"
        echo "                                                          "
        echo " This script sources a specific MOOS directory and runs a specific mission from that directory"
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --script=launch.sh    get the name of the script         "
        echo " --repo=moos-ivp-extend     which repo to run             "
        echo " --mission=missions/alpha,    which mission to run from REPO_NAME"
        echo " --bindir=moos-ivp-extend/bin,    which repo to source for binaries "
        echo "                      (Defaults to repo/bin)              "
        echo " --libdir=moos-ivp-extend/lib,    which repo to add to IVP_BEHAVIOR_DIRS"
        echo "                      (Defaults to repo/lib)              "
        echo "                                                          "
        echo "  --verbose=, -v=      Set verbosity                 "
        echo "  --verbose, -v        Set verbosity=1                 "
        echo " All other arguments will flow down to the launch script"
        exit 0
    elif [[ "${ARGI}" == "--script="* ]]; then
        SCRIPTNAME="${ARGI#*=}"
    elif [[ "${ARGI}" == "--repo="* ]]; then
        REPO_NAME="${ARGI#*=}"
    elif [[ "${ARGI}" == "--mission="* ]]; then
        MISSION_SDIR="${ARGI#*=}"
    elif [[ "${ARGI}" == "--verbose="* || "${ARGI}" == "-v="* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        FLOW_DOWN_ARGS+="${ARGI} "
    fi
done

#-------------------------------------------------------
#  Part 3: Check that args have been set
#-------------------------------------------------------

# Checks that the required parameters have been set
if [[ -z "${REPO_NAME}" ]]; then
    vexit "Repo name not given. Example: --repo=moos-ivp-extend" 2
fi
if [[ -z "${MISSION_SDIR}" ]]; then
    vexit "Mission subdirectory not given. Example: --mission=missions/alpha" 3
fi

#-------------------------------------------------------
#  Part 4: Check that all directories exist on the host
#-------------------------------------------------------

# Checks that the required directories exist
if [[ ! -d "${MONTE_MOOS_CLIENT_REPOS_DIR}/${REPO_NAME}" ]]; then
    vexit "Repo directory/subdirectory $MONTE_MOOS_CLIENT_REPOS_DIR/${REPO_NAME} does not exist! Repo may be empty if the repo_links didn't work" 4
fi

# Find the mission directory
MISSION_DIR="${MONTE_MOOS_CLIENT_REPOS_DIR}/${REPO_NAME}/${MISSION_SDIR}"

if [[ ! -d "${MISSION_DIR}" ]]; then
    MISSION_DIR2="${MONTE_MOOS_CLIENT_REPOS_DIR}/${REPO_NAME}/trunk/${MISSION_SDIR}"
    if [[ ! -d "${MISSION_DIR2}" ]]; then
        vexit "Mission subdirectory ${MISSION_DIR} does exist. ${MISSION_DIR2} was also not found" 5
    else
        MISSION_DIR="${MISSION_DIR2}"
    fi
fi
if [[ ! -f "${MISSION_DIR}/${SCRIPTNAME}" ]]; then
    SCRIPTNAME="trunk/${SCRIPTNAME}"
    if [[ ! -f "${MISSION_DIR}/${SCRIPTNAME}" ]]; then
        vexit "Script ${MISSION_DIR}/${SCRIPTNAME} does exist." 8
    fi
fi

#-------------------------------------------------------
#  Part 6:  Source path, add behavior dirs, run the script
#-------------------------------------------------------
if [[ $TO_SOURCE == "yes" ]]; then
    add_bin "$REPO_NAME"
fi
if [[ $TO_ADD_LIB == "yes" ]]; then
    add_lib "$REPO_NAME"
fi

echo "Launching with PATH $(tput setaf 245)"
mypath
echo "$(tput sgr0)Launching with IVP_BEHAVIOR_DIRS$(tput setaf 245)"
mydirs
echo "$(tput sgr0)"

# Run the launch.sh script with pre-determined flags
cd "$MISSION_DIR" || safe_exit 9

vecho "./$SCRIPTNAME $FLOW_DOWN_ARGS" 1
./$SCRIPTNAME $FLOW_DOWN_ARGS >&/dev/null &
if [ $? -ne 0 ]; then
    vexit "Error running $MISSION_DIR/$SCRIPTNAME. Check that the script does not require confirmation before running." 10
fi
cd - >/dev/null

#-------------------------------------------------------
#  Part 8: Restore the original path to prevent conflicts
#-------------------------------------------------------

safe_exit 0
