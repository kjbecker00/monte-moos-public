#!/bin/bash
# Kevin Becker, Jan 22 2024

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

MYNAME=$(cat ${CARLO_DIR_LOCATION}/myname.txt)
