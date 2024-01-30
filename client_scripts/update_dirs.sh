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
source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh
source /${MONTE_MOOS_BASE_DIR}/lib/lib_repo_updating_utils.sh

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
fi


#-------------------------------------------------------
#  Part 4: Useful functions
#-------------------------------------------------------
#  Updates all necesary repos in an repo_links.txt file
handle_repo_links_file() {
    local repo_links_file=$1
    #-------------------------------------------------------
    #  Git clone/git pull/build.sh all dirs in the file
    #-------------------------------------------------------
    vecho "repo_links file: $repo_links_file" 1
    # Add newline if not present
    [ -n "$(tail -c1 $repo_links_file)" ] && printf '\n' >> "$repo_links_file"

    # For resetting the pwd after each iter
    local starting_pwd=$(pwd)

    # Would prefer to do a while read loop, but
    # The build scripts sometimes throw it off for some reason
    # This works though.
    local file_len=$(wc -l < $repo_links_file)
    for ((counter = 1; counter <= file_len; counter++)); do
        cd $starting_pwd
        local repo_line=$(awk -v num=$counter 'NR==num' $repo_links_file )

        vecho "repo_line=$repo_line" 1

        if skipline $repo_line ; then
            vecho "Skipping line... $repo_line" 10
            continue
        fi
        local repo_name=$(extract_repo_name $repo_line)
        local repo_link=$(extract_repo_link $repo_line)
        vecho "repo_name=$repo_name from repo_line=$repo_line" 1
        echo "     $repo_name"

        #-------------------------------------------------------
        #  Part 4b: Handle mutliple types of repos: git
        if [[ $repo_line == *github.* || $repo_line == *gitlab.* ]]; then
            vecho "  $repo_name is a git repo" 2

            if [ -d "${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name" ]; then
                echo -n "        Updating..."
                cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name
                gpull $repo_name $repo_links_file
                cd ../..
            else
                echo "        Cloning $repo_name..."
                cd ${MONTE_MOOS_CLIENT_REPOS_DIR}
                git clone "$repo_link" "$repo_name" &>/dev/null
                if [ $? -ne 0 ]; then
                    vexit "git clone on $repo_name failed, check $repo_links_file" 2
                fi
                cd ../
            fi


        #-------------------------------------------------------
        #  Part 4b: Handle mutliple types of repos: local repos
        elif [[ "$repo_line" == "~/"* ]] || [[ "$repo_line" == "/"* ]]; then

            # add link if it does not exist
            if [ ! -L "${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo_name}" ]; then
                if [[ "$repo_line" == "~/"* ]]; then
                    repo_line="${repo_line/#\~/$HOME}"
                fi
                if [[ -d "$repo_name" ]]; then
                    echo "        Linking repo..."
                    ln -s "$repo_name" "${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo_name}"
                else
                    vexit "${txtylw}linking to $repo_name failed. Repo does not exist. Check $repo_links_file ${txtrst}" 2
                fi
            fi

            echo -n "        Updating..."
            cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name || (
                echo $txtred "$0 Error unable to cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name (currently in $PWD) exiting..."
                exit 1
            )
            if [ -f ".git" ]; then
                gpull $repo_name $repo_links_file
            elif [[ -f ".svn" || -d ".svn" ]]; then
                svnup $repo_name $repo_links_file
            fi
            cd ../..
        else
            vexit "$repo_line is not a valid repo" 2
        fi

        #-------------------------------------------------------
        #  Part 4c: build the repo
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
            ALL_FLOW_DOWN_ARGS="${FLOW_DOWN_ARGS}"
        fi

        build_script
        BUILD_FAIL=$?
        if [[ -z $BUILD_FAIL ]]; then
            BUILD_FAIL=0
        fi

	if [ $BUILD_FAIL -ne 0 ]; then
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
    done < "$repo_links_file"
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

# TODO, low priority: Add the all option
# if [[ ALL = "yes"  && -z $JOB_FILE ]]; then
#     echo "All repos in ${MONTE_MOOS_BASE_REPO_LINKS} have been updated"
#     echo "Exiting..."
#     exit 0
# fi

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
vecho "Checking if $SHORE_REPO has been built..." 1
if has_not_built_repo "${SHORE_REPO}"; then
    vexit "has not built ${SHORE_REPO}" 1
fi
for repo in "${VEHICLE_REPOS[@]}"; do
    if has_not_built_repo $repo_name; then
        vexit "has not built $repo_name" 1
    fi
done
for repo in "${EXTRA_REPOS[@]}"; do
    if has_not_built_repo $repo_name; then
        vexit "has not built $repo_name" 1
    fi
done
for repo in "{$EXTRA_LIB_REPOS[@]}"; do
    if has_not_built_repo $repo_name; then
        vexit "has not built $repo_name" 1
    fi
done
for repo in "{$EXTRA_BIN_REPOS[@]}"; do
    if has_not_built_repo $repo_name; then
        vexit "has not built $repo_name" 1
    fi
done
if has_not_built_repo moos-ivp; then
    vexit "has not built moos-ivp" 1
fi

exit 0