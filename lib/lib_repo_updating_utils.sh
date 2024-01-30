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

    vecho "      $this_repo_name is not part of this job" 1
    return 1
}

#--------------------------------------------------------------
# Checks if a repo has been built
#--------------------------------------------------------------
has_not_built_repo() {
    local repo
    local name
    local num
    local num2
    repo=$1

    if [ -f "$built_dirs_cache" ]; then
        num=$(grep -Fx -m 1 "$repo" "$built_dirs_cache")
        if [ -z "$num" ]; then
            return 1
        fi
        name=$(extract_repo_name "$repo")
        num2=$(grep -Fx -m 1 "$name" "$built_dirs_cache")
        if [ -z "$num2" ]; then
            return 1
        fi
    fi
    return 0
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
    echo $txtgrn " updated sucessfully" $txtrst
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
    echo $txtgrn " updated sucessfully" $txtrst
}

#--------------------------------------------------------------
# Determines if you should skip over a line
#--------------------------------------------------------------
skipline() {
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
    if [ $ALL != "yes" ]; then
        if has_not_built_repo "$repo_name" ; then
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
build_script() {
    starting_dir="$PWD"
    if [ ! -f "$script" ]; then
        if [ -f trunk/"$script" ]; then
            cd trunk
        else
            vexit "      can't find build script as $PWD/$script or $PWD/$trunk/$script" 1
        fi
    fi

    # Remove old build log, if it exists
    rm -f .build_log.txt

    # Quietly try to build the script as is
    if [[ $QUIET == "yes" ]]; then
        ./$script "${ALL_FLOW_DOWN_ARGS}" >.build_log.txt 2>&1
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
