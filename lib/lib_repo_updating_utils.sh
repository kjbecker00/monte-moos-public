#!/bin/bash
# Kevin Becker, Jan 23, 2024
#--------------------------------------------------------------
# These scripts are utils for adding/removing bash
# variables to the path/IVP_BEHAVIOR_DIRS
#--------------------------------------------------------------

#--------------------------------------------------------------
# determines if a repo is in the already referenced job file
#--------------------------------------------------------------
is_in_job() {
    local this_repo_name="${1}"
    if [[ "$SHORE_REPO" == "$this_repo_name" ]]; then
        vecho "$this_repo_name in SHORE_REPO" 3
        return 0
    fi
    for repo in "${VEHICLE_REPOS[@]}" "${EXTRA_REPOS[@]}" "${EXTRA_LIB_REPOS[@]}" "${EXTRA_BIN_REPOS[@]}"; do
        if [[ "$repo" == "$this_repo_name" ]]; then
            vecho "$this_repo_name in job" 3
            return 0
        fi
    done

    if [[ "$this_repo_name" == "moos-ivp" ]]; then
        vecho "$this_repo_name in job" 3
        return 0
    fi

    vecho "      $this_repo_name is not part of this job" 1
    return 1
}

#--------------------------------------------------------------
# Checks if a repo has been built
#--------------------------------------------------------------
has_not_built_repo() {
    local repo_name
    local num
    repo_name=$1
    built_dirs_cache="${CARLO_DIR_LOCATION}/.built_dirs"
    if [ -f "$built_dirs_cache" ]; then
        num=$(grep -Fx -m 1 "$repo_name" "$built_dirs_cache")
        # vecho "grep -Fx -m 1 \"$repo_name\" \"$built_dirs_cache\"" 10
        # vecho "num=$num" 10
        if [ -z "$num" ]; then
            # Repo not found. need to build
            return 0
        fi
    fi
    if [[ ! -d "$MONTE_MOOS_CLIENT_REPOS_DIR/$repo_name"/bin ]]; then
        return 0 # repo bin directory does not exist. Need to build
    fi
    return 1
}

#--------------------------------------------------------------
# given a line in a repo_links file, retrieves the repo name
#--------------------------------------------------------------
extract_repo_name() {
    local repo_full
    repo_full=$(echo "$1" | xargs)
    local repo_name
    repo_name="$(echo "$repo_full" | awk '{print $2}')"

    if [[ $repo_name = "" ]]; then
        if [[ $repo_full =~ \.git$ ]]; then
            repo_name=$(basename "$repo_full" .git)
        elif [[ $repo_full == *github.* || $repo_full == *gitlab.* ]]; then
            repo_name=$(basename "$repo_full")
        elif [[ "$repo_full" == "~/"* ]] || [[ "$repo_full" == "/"* ]]; then
            # repo_name="${repo_full##*/}" Old version
            repo_name="$(basename $repo_full)"
        else
            echo "$0 Error: Repo type not recognized: \"$repo_full\""
        fi
    fi
    echo "$repo_name"
}

#--------------------------------------------------------------
# given a line in a repo_links file, retrieves the repo name
#--------------------------------------------------------------
extract_repo_link() {
    #  trim the repo name
    local trimmed
    trimmed=$(echo "$1" | xargs)

    # split by spaces
    # return the first element
    echo "$trimmed" | awk '{print $1}'
}

#--------------------------------------------------------------
# Wrapper for git pull (note: alter return if no changes)
#--------------------------------------------------------------
gpull() {
    local repo_name=$1
    local repo_links_file=$2
    git pull &>/dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "    ${txtylw}Warning: git pull on $repo_name failed, check $repo_links_file ${txtrst}"
    fi
    echo $txtgrn"        updated sucessfully" $txtrst
}

#--------------------------------------------------------------
# Wrapper for svn up (note: alter return if no changes)
#--------------------------------------------------------------
svnup() {
    local repo_name
    repo_name=$1
    local repo_links_file
    repo_links_file=$2
    svn up &>/dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "    ${txtylw}Warning: svn up on $repo_name failed, check $repo_links_file ${txtrst}"
    fi
    echo $txtgrn"        updated sucessfully" $txtrst
}

#--------------------------------------------------------------
# Determines if you should skip over a line in a
# repo_links.txt file
#--------------------------------------------------------------
to_skip_repo_line() {
    local repo=$1
    if [[ $repo == "" ]]; then
        vecho "Identified as blank line... $repo" 10
        return 0
    fi
    if [[ $repo == \#* ]]; then
        vecho "Identified as comment... $repo" 10
        return 0
    fi
    repo_name=$(extract_repo_name "$repo")
    vecho "repo=$repo repo_name=$repo_name" 1
    if [ "$ALL" != "yes" ]; then
        if ! has_not_built_repo "$repo_name"; then
            echo "      ${repo_name} ${txtgrn} Already built. skipping...${txtrst}"
            return 0
        else
            vecho "      ${repo_name} not built. May be building...${txtrst}" 1
        fi
        # Determines if the repo is used for the job
        if is_in_job "$repo_name"; then
            echo "      Updating & building $repo_name..."
            return 1
        else
            echo $txtgry "     $repo_name is not part of this job. Skipping..." $txtrst
            return 0
        fi
    fi
    return 0
}

#--------------------------------------------------------------
# Wrapper for build script
#--------------------------------------------------------------
run_build_script() {
    starting_dir="$PWD"
    if [ ! -f "$script" ]; then
        if [ -f trunk/"$script" ]; then
            cd trunk || vexit "      can't find trunk directory, but found file in trunk/script?" 1
        else
            vexit "      can't find build script as $PWD/$script or $PWD/trunk/$script" 1
        fi
    fi

    # Remove old build log, if it exists
    rm -f .build_log.txt

    # Quietly try to build the script as is
    if [[ $QUIET == "yes" ]]; then
        ./"$script" "${ALL_FLOW_DOWN_ARGS}" >.build_log.txt 2>&1
    else
        ./$script "${ALL_FLOW_DOWN_ARGS}" >.build_log.txt
    fi
    BUILD_FAIL=$?
    if tail -1 ".build_log.txt" | grep -iq "error"; then
        BUILD_FAIL=1
    fi

    # If the build fails, try cleaning and rebuilding
    if [[ $BUILD_FAIL -ne 0 ]]; then
        echo "        build failed. Cleaning and retrying..."

        # cleaning
        if [[ -f ./clean.sh ]]; then
            ./clean.sh 2>&1
        else
            ./$script --clean 2>&1
        fi

        # re-building
        if [[ $QUIET == "yes" ]]; then
            ./$script "${ALL_FLOW_DOWN_ARGS}" >.build_log.txt 2>&1
        else
            ./$script "${ALL_FLOW_DOWN_ARGS}" >.build_log.txt
        fi
        BUILD_FAIL=$?
        if tail -1 ".build_log.txt" | grep -iq "error"; then
            BUILD_FAIL=1
        fi
    fi
    cd "$starting_dir"
    return $BUILD_FAIL
}

#-------------------------------------------------------
#  git pulls/svn ups the repo in question
#-------------------------------------------------------
update_repo() { # $repo_name $repo_link
    local repo_name
    repo_name=$1
    local repo_link
    repo_link=$2
    local my_pwd
    my_pwd=$(pwd)

    cd "${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name" || vexit "unable to cd ${MONTE_MOOS_CLIENT_REPOS_DIR}/$repo_name" 2
    if [ -d .git ]; then
        gpull $repo_name $repo_links_file
    elif [[ -f ".svn" || -d ".svn" ]]; then
        svnup $repo_name $repo_links_file
    fi
}

#-------------------------------------------------------
#  git clone/svn co/ln -s the repo in question
#-------------------------------------------------------
clone_repo() { # $repo_name $repo_link
    local repo_name
    repo_name=$1
    local repo_link
    repo_link=$2}
    local my_pwd
    my_pwd=$(pwd)

    cd "${MONTE_MOOS_CLIENT_REPOS_DIR}" || vexit "Unable to cd ${MONTE_MOOS_CLIENT_REPOS_DIR}" 2
    vecho "  Cloning $repo_name..." 2
    #-------------------------------------------------------
    #  git
    if [[ $repo_link == *github.* || $repo_link == *gitlab.* ]]; then
        vecho "  $repo_name is a git repo" 2
        echo "        Cloning $repo_name..."
        git clone "$repo_link" "$repo_name" &>/dev/null
        if [ $? -ne 0 ]; then
            vexit "git clone on $repo_name failed, check $repo_links_file" 2
        fi
        cd "$my_pwd" || vexit "Error cd'ing into pwd?" 100
    #-------------------------------------------------------
    #  local repos
    elif [[ "$repo_link" == "~/"* ]] || [[ "$repo_link" == "/"* ]]; then
        # Replace ~ with $HOME
        if [[ "$repo_link" == "~/"* ]]; then
            repo_link="${repo_link/#\~/$HOME}"
        fi

        if [[ -d "$repo_link" ]]; then
            echo "        Linking $repo_name to moos dirs..."
            ln -s "$repo_link" "${MONTE_MOOS_CLIENT_REPOS_DIR}/${repo_name}"
        else
            vexit "${txtylw}linking to $repo_name failed. Repo does not exist. Check $repo_links_file ${txtrst}" 2
        fi

        # Now that the repo is linked, we can update it via svn or git
        update_repo $repo_name $repo_link
    #-------------------------------------------------------
    #  local repos
    elif [[ $repo_link == *.oceanai.* ]]; then
        vecho "  $repo_name is a svn repo" 2
        echo "        Cloning $repo_name..."
        svn co "$repo_link" "$repo_name" &>/dev/null
        if [ $? -ne 0 ]; then
            vexit "svn co $repo_name failed, check $repo_links_file" 2
        fi
        cd "$my_pwd" || vexit "Error cd'ing into pwd?" 100
    else
        vexit "$repo_line is not a valid repo" 2
    fi
}
