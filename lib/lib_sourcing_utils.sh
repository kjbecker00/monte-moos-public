#!/bin/bash
# Kevin Becker, Jan 23, 2024
#--------------------------------------------------------------
# These scripts are utils for adding/removing bash variables
# to the path/IVP_BEHAVIOR_DIRS
#--------------------------------------------------------------

#--------------------------------------------------------------
# Finds the expanded path of a repo, given a repo name
#--------------------------------------------------------------
find_repo_location() {
    repo="$1"
    # If the repo is in the home directory, expand it
    if [[ "$repo" == "~/"* ]]; then
        repo="${repo/#\~/$HOME}"
    else
        # Look for repo in carlo_dir/moos_dirs/
        if [[ -d "${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo}" ]]; then
            repo="${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo}"
        # If given a full, expanded path anyways, use that
        elif [[ -d $repo ]]; then
            : # File exists!
        else
            vexit "unable to find ${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo} or $repo" 1
        fi
    fi
    echo "$repo"
}

#--------------------------------------------------------------
# Adds a repo's IVP_BEHAVIOR_DIRS
#--------------------------------------------------------------
add_lib() {
    repo=$(find_repo_location "$1")

    vecho "Adding ${repo}'s lib, to IVP_BEHAVIOR_DIRS..." 1
    if [[ -d ${repo}/lib ]]; then
        IVP_BEHAVIOR_DIRS=$IVP_BEHAVIOR_DIRS:${repo}/lib
    elif [[ -d ${repo}/trunk/lib ]]; then
        IVP_BEHAVIOR_DIRS=$IVP_BEHAVIOR_DIRS:${repo}/trunk/lib
    else
        vexit "unable to find ${repo}/trunk/lib or ${repo}/lib" 1
    fi
    export IVP_BEHAVIOR_DIRS
}

#--------------------------------------------------------------
# Adds a repo's binaries, scripts to the path
#--------------------------------------------------------------
add_bin() {
    repo=$(find_repo_location "$1")

    vecho "Adding ${repo}'s bin and scripts, to $PATH..." 1
    if [[ -d ${repo}/bin ]]; then
        PATH=$PATH:${repo}/bin
        PATH=$PATH:${repo}/scripts
    elif [[ -d ${repo}/trunk/bin ]]; then
        PATH=$PATH:${repo}/trunk/bin
        PATH=$PATH:${repo}/trunk/scripts
    else
        vexit "unable to find ${repo}/trunk/bin or ${repo}/bin" 1
    fi
    export PATH
}

#--------------------------------------------------------------
# Adds a repo's binaries, scripts, and libraries to the path
#--------------------------------------------------------------
add_repo() {
    repo="${1}"
    add_lib "$repo"
    add_bin "$repo"
}

#--------------------------------------------------------------
# Adds all the extra repos reverenced in the job to the path
#--------------------------------------------------------------
add_extra_repos_to_path() {
    #  Part 1 EXTRA_REPOS
    EXTRA_REPO_COUNT=${#EXTRA_REPOS[@]}
    for ((i = 0; i < EXTRA_REPO_COUNT; i++)); do
        vecho "Sourcing ${EXTRA_REPOS[i]}..." 1
        repo="${EXTRA_REPOS[i]}"
        add_repo "$repo"
    done

    #  Part 2: Extra binaries
    EXTRA_BIN_COUNT=${#EXTRA_BIN_REPOS[@]}
    for ((i = 0; i < EXTRA_BIN_COUNT; i++)); do
        vecho "Sourcing ${EXTRA_BIN_REPOS[i]}..." 1
        repo="${EXTRA_BIN_REPOS[i]}"
        add_bin "$repo"
    done

    #  Part 3: Extra libraries for ivp behaviors
    EXTRA_LIB_COUNT=${#EXTRA_LIB_REPOS[@]}
    for ((i = 0; i < EXTRA_LIB_COUNT; i++)); do
        vecho "Sourcing ${EXTRA_LIB_REPOS[i]}..." 1
        repo="${EXTRA_LIB_REPOS[i]}"
        add_lib "$repo"
    done

}

#--------------------------------------------------------------
# Echos everything in the current path
#--------------------------------------------------------------
mypath() {
    AMT=75
    for INDEX in $(seq 1 $AMT); do
        PART=$(echo $PATH | cut -d : -f $INDEX)
        if [ "${PART}" = "" ]; then
            continue
        fi
        echo "     $PART"
    done
}

#--------------------------------------------------------------
# Echos everything in the current IVP_BEHAVIOR_DIRS
#--------------------------------------------------------------
mydirs() {
    AMT=75
    for INDEX in $(seq 1 $AMT); do
        PART=$(echo $IVP_BEHAVIOR_DIRS | cut -d : -f $INDEX)
        if [ "${PART}" = "" ]; then
            continue
        fi
        echo "     $PART"
    done
}

#--------------------------------------------------------------
# Removes something from a path-like string. Returns the new
# value of that path-like string
#--------------------------------------------------------------
remove_from_pathlike_string() {
    INDEX=0
    output_var=":"
    # Uses ##END_OF_PATH## because sometimes
    # two ':'s are put next to each other in the path
    INPUT="${1}:##END_OF_PATH##"
    while [ 1 ]; do
        INDEX=$((INDEX + 1))
        PART=$(echo $INPUT | cut -d : -f $INDEX)
        vecho "$PART" 30
        if [[ "${PART}" = "##END_OF_PATH##" ]]; then
            break
        elif [[ "${PART}" = $2 ]]; then
            vecho "   SKIPPING" 30
            continue
        else
            vecho "ADDING..." 30
            output_var+="$PART:"
        fi
    done
    output_var="${output_var%:}"

    output_var="${output_var//::/:}" # Replace :: with :
    output_var="${output_var//::/:}" # Replace :: with : (again)
    echo "$output_var"
}
