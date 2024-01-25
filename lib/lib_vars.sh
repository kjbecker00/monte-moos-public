#!/bin/bash
# Kevin Becker, Jan 22 2024
#--------------------------------------------------------------
# This initalizes many variables used by other scripts
#--------------------------------------------------------------

VERBOSE=0
original_path=$PATH
original_ivp_behavior_dirs=$IVP_BEHAVIOR_DIRS
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold


# Get myname. If it is not set, then set it
if [[ -f ${CARLO_DIR_LOCATION}/myname.txt ]]; then
    MYNAME=$(head -n 1 ${CARLO_DIR_LOCATION}/myname.txt)
fi

if [[ -z $MYNAME ]]; then
    if [ -f "/home/student2680/pablo-common/bin/get_vname.sh" ]; then
        MYNAME="$(/home/student2680/pablo-common/bin/get_vname.sh)"
    else
        MYNAME="$(hostname)"
    fi
    echo "$name" >"${CARLO_DIR_LOCATION}/myname.txt"
fi
