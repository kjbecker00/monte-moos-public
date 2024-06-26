#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/03/2023
# Script: update_dirs2.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="update_dirs.sh"
# build script name (indluce any flags here or as flow-down args)
script="build.sh"
# shellcheck disable=SC2034
QUIET="yes" # quiet mode for build.sh
built_dirs_cache="${CARLO_DIR_LOCATION}/.built_dirs"
# args to get passed on to "script"
FLOW_DOWN_ARGS=""
ALL="no"
PROMPT_TIMEOUT=20
# shellcheck disable=SC1090
source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_include.sh
# shellcheck disable=SC1090
source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_repo_updating_utils.sh

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh --job_file=[] [OPTIONS] "
        echo "                                                          "
        echo "  Updates and builds the required moos-dirs for a given job."
        echo "                                                          "
        echo "Options: "
        echo " --help, -h    Show this help message "
        echo "  --verbose=num, -v=num or --verbose, -v"
        echo "    Set verbosity                                     "
        echo " --job_file=    set the name of the job file (only updates dirs that apply to this job) "
        echo " --job_args=    set the arguments to pass to the job "
        # echo " --all, -a      update everything it has a repo_links.txt file for"
        echo " All other arguments will flow down to the build script (e.g. -j8 for 8 cores)"
        exit 0
    elif [[ "${ARGI}" == "--job_file="* ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [[ "${ARGI}" == "--job_args="* ]]; then
        JOB_ARGS="${ARGI#*=}"
    # elif [ "${ARGI}" = "--all" -o "${ARGI}" = "-a" ]; then
    #     ALL="yes"
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
#  Part 3: Source Job File
#-------------------------------------------------------
if [ $ALL = "yes" ]; then
    echo $txtblu $(tput bold) "Updating all repos in ${MONTE_MOOS_BASE_REPO_LINKS}" $txtrst
else
    . "$JOB_FILE" $JOB_ARGS
fi
if [ ! -d ${MONTE_MOOS_CLIENT_REPOS_DIR} ]; then
    mkdir ${MONTE_MOOS_CLIENT_REPOS_DIR}
fi
if [ ! -f $built_dirs_cache ]; then
    touch $built_dirs_cache
    echo "# .built_dirs file created by update_dirs.sh" >>$built_dirs_cache
    echo "# This file tracks which moos-dirs are up to " >>$built_dirs_cache
    echo "# date and built. " >>$built_dirs_cache

fi

#-------------------------------------------------------
#  Part 4: Useful functions
#-------------------------------------------------------
#  Updates all necesary repos in an repo_links.txt file
handle_repo_links_file() {
    local repo_links_file
    repo_links_file=$1

    local repo_line
    local starting_pwd
    local file_len
    local repo_name
    local repo_link
    #-------------------------------------------------------
    #  Git clone/git pull/build.sh all dirs in the file
    #-------------------------------------------------------
    vecho "#################################" 1
    vecho "repo_links file: $repo_links_file" 1
    # Add newline if not present
    [ -n "$(tail -c1 $repo_links_file)" ] && printf '\n' >>"$repo_links_file"

    # For resetting the pwd after each iter
    starting_pwd=$(pwd)

    # Would prefer to do a while read loop, but
    # The build scripts sometimes throw it off for some reason
    # This works though.
    file_len=$(wc -l <$repo_links_file)
    for ((counter = 1; counter <= file_len; counter++)); do
        cd "$starting_pwd" || vexit "Error cd'ing into old pwd?" 100

        repo_line=$(awk -v num=$counter 'NR==num' $repo_links_file)
        if to_skip_repo_line $repo_line; then
            vecho "Skipping line... $repo_line" 10
            continue
        fi
        repo_name=$(extract_repo_name $repo_line)
        repo_link=$(extract_repo_link $repo_line)

        #-------------------------------------------------------
        # Update or clone the repo
        if [ -d "${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name" ]; then
            update_repo $repo_name $repo_link
            if [[ $? -ne 0 ]]; then
                vexit "Error updating $repo_name with link: $repo_link" 10
            fi
        else
            clone_repo $repo_name $repo_link
            if [[ $? -ne 0 ]]; then
                vexit "Error cloning $repo_name with link: $repo_link" 11
            fi
        fi

        #-------------------------------------------------------
        #  Build the repo
        cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/"$repo_name" || (vexit "unable to cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name " 2)
        echo -n "        Building..."

        ##############################################
        # SVN repos were developed in the lab.       #
        # these repos should be built with -m to     #
        # ensure they can run a shoreside as well    #
        ##############################################
        if [[ -f ".svn" || -d ".svn" ]]; then
            ALL_FLOW_DOWN_ARGS="${FLOW_DOWN_ARGS} -m"
        else
            # shellcheck disable=SC2034 # ALL_FLOW_DOWN_ARGS is used in run_build_script
            ALL_FLOW_DOWN_ARGS="${FLOW_DOWN_ARGS}"
        fi

        run_build_script
        BUILD_FAIL=$?
        if [[ -z $BUILD_FAIL ]]; then
            BUILD_FAIL=0
        fi

        if [ $BUILD_FAIL -ne 0 ]; then
            # svn repos not building isn't fatal, but git repos are fatal
            if [[ -f ".svn" || -d ".svn" ]]; then
                wecho "build failed on $repo_name. Check $repo_name/.build_log.txt"
            else
                vexit "build failed on $repo_name with exit code $?" 3
            fi
        fi
        wait
        echo $txtgrn " built sucessfully" $txtrst
        cd ../.. >/dev/null || exit 1
        echo "$repo_name" >>$built_dirs_cache
    done <"$repo_links_file"
}

#-------------------------------------------------------
#  Part 5: Add cmake to path if not already there
#-------------------------------------------------------
if type cmake >/dev/null 2>&1; then
    true
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -d "/opt/homebrew/bin" ]; then
            PATH=$PATH:/opt/homebrew/bin
        else
            vexit "Directory /opt/homebrew/bin not found in $0. Please install cmake with brew or edit this file." 1
        fi
    else
        PATH=$PATH:/usr/local/bin
        PATH=$PATH:/usr/bin
    fi
    export PATH
fi
if type cmake >/dev/null 2>&1; then
    true
else
    vexit "make not found. Please fix and try again" 1
fi

#-------------------------------------------------------
#  Part 6: Loop through and finds each repo_links.txt file
#-------------------------------------------------------
handle_repo_links_file "${MONTE_MOOS_BASE_REPO_LINKS}"
# loop through all repo_links.txt files in the JOB_DIR and all of its parent directories

SEARCH_DIR=$(dirname $JOB_FILE)
SEARCH_DIR_BASE="${SEARCH_DIR%%/*}/../.."
vecho "Starting search with $SEARCH_DIR, going to $SEARCH_DIR_BASE" 1

while [[ "$SEARCH_DIR" != "$SEARCH_DIR_BASE" && "$SEARCH_DIR" != "$LAST_SEARCH_DIR" ]]; do
    LAST_SEARCH_DIR=$SEARCH_DIR
    vecho "Searching for repo_links.txt in $SEARCH_DIR until reaching $SEARCH_DIR_BASE" 3
    if [ -f "$SEARCH_DIR/repo_links.txt" ]; then
        vecho "     Found $SEARCH_DIR/repo_links.txt" 1
        array+=("$SEARCH_DIR/repo_links.txt")
    else
        vecho "     Did not find a repo_links.txt in $SEARCH_DIR" 5
    fi
    SEARCH_DIR=$(dirname $SEARCH_DIR)
done

# Loop through repo links in descending order
# More natural to have dependencies in this manner
for ((i = ${#array[@]} - 1; i >= 0; i--)); do
    handle_repo_links_file "${array[i]}"
done

#-------------------------------------------------------
#  Part 7: Check that every required repo has been updated
#-------------------------------------------------------
# Check that all repos have been built
vecho "" 1
vecho "" 1
vecho "Checking if $SHORE_REPO has been built..." 1
VEHICLE_REPOS+=("${SHORE_REPO}")
for repo_name in "${VEHICLE_REPOS[@]}" "${EXTRA_REPOS[@]}" "${EXTRA_LIB_REPOS[@]}" "${EXTRA_BIN_REPOS[@]}"; do
    if has_not_built_repo "$repo_name"; then
        vexit "has not built ${repo_name}. Ensure there is a repo_link for this repository in your repo_links.txt" 1
    fi
done
if has_not_built_repo moos-ivp; then
    vexit "has not built moos-ivp" 1
fi

exit 0
