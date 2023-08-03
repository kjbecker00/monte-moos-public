#!/bin/bash
# Kevin Becker, May 26 2023

# Example:
# ./source_launch.sh mylaunch moos-ivp-extend "missions/lab_05/alpha_return" 10
#          runs ./mylaunch.sh in missions/lab_05/alpha_return with timewarp 10
    
#-------------------------------------------------------
#  Part 1: Initalize the variables
#-------------------------------------------------------
# Get the directory name and mission dir bname from the first 2 arguments
SCRIPTNAME="launch"
R_SDIR=""
BIN_SDIR=""
LIB_SDIR=""
MISSION_SDIR=""
FLOW_DOWN_ARGS="" # Get the mission name from the third argument
REPO_DIR="${PWD}/moos-dirs" # or REPO_DIR="${HOME}"
TO_SOURCE="yes"   # if the script should add repo/bin to the path
TO_ADD_LIB="yes"  # if the script should add repo/lib to IVP_BEHAVIOR_DIRS
original_ivp_behavior_dirs=$PATH
original_ivp_behavior_dirs=$IVP_BEHAVIOR_DIRS

ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green                     
txtylw=$(tput setaf 3) # Yellow                     
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey                     
txtbld=$(tput bold)    # Bold                           
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi }
secho() {   echo "$1"
            [ -f "myname.txt" ] || { echo "$(hostname)" > myname.txt ; }
            name=$(head -n 1 myname.txt)
            echo "$1 (on ${name} as of $(date))" > status.txt ; 
            # Start ssh-agent
            eval `ssh-agent -s` &> /dev/null
            ps -p $SSH_AGENT_PID &> /dev/null
            SSH_AGENT_RUNNING=$?
            [ ${SSH_AGENT_RUNNING} -eq 0 ] || { vecho "Unable to start ssh-agent" 3 ; }
            ssh-add -t 7200 ~/.ssh/id_rsa_yco 2> /dev/null
            [ "$?" -eq "0" ] || { vexit "ssh agent unable to add yco key" 3 ; }
            ssh -n "yodacora@oceanai.mit.edu" "mkdir -p ~/monte-moos/clients/status" &> /dev/null
            EXIT_CODE=$?
            if [ ! $EXIT_CODE -eq "0" ]; then
                if [ $EXIT_CODE -eq 255 ]; then
                    vecho "$txtylw Warning: ssh unable to connect. Continuing..."$txtrst 0
                fi
            fi
            rsync -zaPr -q status.txt "yodacora@oceanai.mit.edu:~/monte-moos/clients/status/${name}.txt" &> /dev/null
             } # status echo
vexit() { secho $txtred"$ME: Error $1. Exit Code $2" $txtrst; safe_exit "$2" ; }
safe_exit() {
    PATH=$original_ivp_behavior_dirs
    IVP_BEHAVIOR_DIRS=$original_ivp_behavior_dirs
    export PATH
    export IVP_BEHAVIOR_DIRS
    if [ $1 -ne 0 ]; then
        echo ""
        echo "${txtred}$ME Exiting safely. Resetting PATH and IVP_BEHAVIOR_DIRS... ${txtrst}"
    fi
    exit $1
}
trap ctrl_c INT
ctrl_c () {
    safe_exit 130
}

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --script=[SCRIPT_NAME] --repo=[REPO_NAME] --mission=[SUBDIRECTORy] [FLOW_DOWN_ARGS]"
        echo " This script sources a specific MOOS directory and runs a specific mission from that directory"
        echo "Options:                                                  " 
        echo " --help, -h Show this help message                        " 
        echo " --script=launch.sh    get the name of the script         " 
        echo " --repo=moos-ivp-extend     which repo to run             " 
        echo " --repodir=PWD/moos-dirs/,    directory to find which repo to run   "
        echo "                              (defaults to PWD/moos-dirs)" 
        echo " --mission=missions/alpha,    which mission to run from REPO_NAME" 
        echo " --bindir=moos-ivp-extend/bin,    which repo to source for binaries " 
        echo "                      (Defaults to repo/bin)              "  
        echo " --libdir=moos-ivp-extend/lib,    which repo to add to IVP_BEHAVIOR_DIRS"
        echo "                      (Defaults to repo/lib)              "
        echo "                                                          " 
        echo " All other arguments will flow down to the launch script"
        exit 0;
    elif [[ "${ARGI}" =~ "--script=" ]]; then
        SCRIPTNAME="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--repo=" ]]; then
        R_SDIR="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--repodir=" ]]; then
        REPO_DIR="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--mission=" ]]; then
        MISSION_SDIR="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--bindir=" ]]; then
        BIN_SDIR="${ARGI#*=}"
    elif [[ "${ARGI}" =~ "--libdir=" ]]; then
        LIB_SDIR="${ARGI#*=}"
    else 
        FLOW_DOWN_ARGS+="${ARGI} "
    fi
done


#-------------------------------------------------------
#  Part 3: Check that args have been set
#-------------------------------------------------------

# Set defaults (if not already set)
if [[ -z "${BIN_SDIR}" ]]; then
    BIN_SDIR="bin"
fi
if [[ -z "${LIB_SDIR}" ]]; then
    LIB_SDIR="lib"
fi

# Checks that the required parameters have been set
if [[ -z "${R_SDIR}" ]]; then
    vexit "Repo name not given. Example: --repo=moos-ivp-extend" 2
fi
if [[ -z "${MISSION_SDIR}" ]]; then
    vexit "Mission subdirectory not given. Example: --mission=missions/alpha" 3
fi


#-------------------------------------------------------
#  Part 4: Check that all directories exist on the host
#-------------------------------------------------------

# Checks that the required directories exist
if [[ ! -d "${REPO_DIR}/${R_SDIR}" ]]; then
    vexit "Repo directory/subdirectory $REPO_DIR/${R_SDIR} does not exist! Repo may be empty if the repo_links didn't work" 4
fi

# Set the full path from the given subdirectories
BIN_DIR="${REPO_DIR}/${R_SDIR}/${BIN_SDIR}"
LIB_DIR="${REPO_DIR}/${R_SDIR}/${LIB_SDIR}"
MISSION_DIR="${REPO_DIR}/${R_SDIR}/${MISSION_SDIR}"

if [[ ! -d "${MISSION_DIR}" ]]; then
  vexit "Mission subdirectory ${MISSION_DIR} does exist." 5
fi
if [[ $TO_SOURCE == "yes" ]]; then
    if [[ ! -d "${BIN_DIR}" ]]; then
      vexit "Binary subdirectory ${BIN_DIR} does exist." 6
    fi
fi
if [[ $TO_ADD_LIB == "yes" ]]; then
    if [[ ! -d "${LIB_DIR}" ]]; then
      vexit "Library subdirectory ${LIB_DIR} does exist." 7
    fi
fi
if [[ ! -f "${MISSION_DIR}/${SCRIPTNAME}" ]]; then
  vexit "Script ${MISSION_DIR}/${SCRIPTNAME} does exist." 8
fi

#-------------------------------------------------------
#  Part 6: Save old values of PATH and IVP_BEHAVIOR_DIRS
#    Source path, add behavior dirs, run the script
#-------------------------------------------------------
original_path=$PATH
original_ivp_behavior_dirs=$IVP_BEHAVIOR_DIRS
    
if [[ $TO_SOURCE == "yes" ]]; then
    vecho "Temporarially adding $BIN_DIR to PATH" 1
    export PATH=$PATH:$BIN_DIR
fi
if [[ $TO_ADD_LIB == "yes" ]]; then
    vecho "Temporarially adding $LIB_DIR to PATH" 1
    export IVP_BEHAVIOR_DIRS=$IVP_BEHAVIOR_DIRS:$LIB_DIR
fi

# Run the launch.sh script with pre-determined flags
cd "$MISSION_DIR" || safe_exit 9
vecho "./$SCRIPTNAME $FLOW_DOWN_ARGS" 1
./$SCRIPTNAME $FLOW_DOWN_ARGS >& /dev/null &
if [ $? -ne 0 ]; then
    vexit "Error running $MISSION_DIR/$SCRIPTNAME" 10
fi
cd - > /dev/null

#-------------------------------------------------------
#  Part 8: Restore the original path to prevent conflicts
#-------------------------------------------------------
export PATH=$original_path
export IVP_BEHAVIOR_DIRS=$original_ivp_behavior_dirs


