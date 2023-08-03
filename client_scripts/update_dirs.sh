#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/03/2023
# Script: update_dirs2.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
# build script name (indluce any flags here or as flow-down args)
script="build.sh"
repo_links="repo_links.txt"
# args to get passed on to "script"
FLOW_DOWN_ARGS=""
QUIET="yes" 
ALL="no"
PROMPT_TIMEOUT=20
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi }
wecho() { echo ${txtylw}"$ME: $1" ${txtrst} ; }
vexit() { echo ${txtred}"$ME: Error $1. Exit Code $2" ${txtrst} ; exit "$2" ; }

#-------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [OPTIONS] "
        echo "  Updates and builds moos-dirs"
        echo "Options: " 
        echo " --help, -h    Show this help message " 
        echo "  --verbose=num, -v=num or --verbose, -v"
        echo "    Set verbosity                                     "
        echo " --job_file=    set the name of the job file (only updates dirs that apply to this job) " 
        echo " --all, -a      update everything it has a repo_links.txt for" 
        echo " All other arguments will flow down to the build script (e.g. -j8 for 8 cores)"
        exit 0;
    elif [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [ "${ARGI}" = "--all" -o "${ARGI}" = "-a" ] ; then
	    ALL="yes"
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
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
    echo $txtblu $(tput bold) "Updating all repos in $repo_links" $txtrst
else
    . "$JOB_FILE"
fi


#--------------------------------------------------------------
#  Part 4: Useful functions
#--------------------------------------------------------------
# determines if a repo is in the job file
is_in_job() {
    local this_repo_name="${1}"
    if [[ "$SHORE_REPO" == "$this_repo_name" ]]; then
        return 0
    elif [[ "${VEHICLE_REPOS[@]}" =~ "$this_repo_name" ]]; then
        return 0
    elif [[ "${EXTRA_REPOS[@]}" =~ "$this_repo_name" ]]; then
        return 0
    elif [[ "${EXTRA_LIB_REPOS[@]}" =~ "$this_repo_name" ]]; then
        return 0
    elif [[ "${EXTRA_BIN_REPOS[@]}" =~ "$this_repo_name" ]]; then
        return 0
    fi
    vecho "      $this_repo_name is not part of this job" 1
    return 1
}
# Checks if a repo has been built
has_built_repo() {
    local repo=$1
    num=$(grep -Fx -m 1 "$repo" .built_dirs)
    if [ ! -z "$num" ]; then
        return 0
    fi
    return 1
}
# given a line in repo_links.txt, retrieves the repo name
extract_repo_name() {
    local repo_full=$1
    local repo_name=""
    if [[ $repo_full =~ \.git$ ]]; then
        repo_name=$(basename "$repo_full" .git) 
    elif [[ "$repo_full" == "~/"* ]] || [[ "$repo_full" == "/"* ]]; then
        # repo_name="${repo_full##*/}" Old version
        repo_name="$(basename $repo_full)"
    else
        echo "$0 Error: Repo type not recognized: $repo_full"
        exit 1 
    fi
    echo $repo_name
}
# Wrapper for git pull
gpull() {
    local repo=$1
    local repo_links_file=$2
    git pull &> /dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "    ${txtylw}Warning: git pull on $repo failed, check $repo_links_file ${txtrst}" 
    fi
    echo $txtgrn " updated sucessfully" $txtrst
}
# Wrapper for svn up
svnup() {
    local repo=$1
    local repo_links_file=$2
    svn up &> /dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "    ${txtylw}Warning: svn up on $repo failed, check $repo_links_file ${txtrst}" 
    fi
    echo $txtgrn " updated sucessfully" $txtrst
}
# Determines if you should skip over a line in repo_links.txt
skipline() {
    local repo=$1
    if [[ $repo == "" ]]; then
        vecho "Skipping blank line... $repo" 10
        return 0
    fi
    if [[ $repo == \#* ]]; then
        vecho "Skipping comment... $repo" 10
        return 0
    fi
    repo_name=$(extract_repo_name $repo)
    if [[ "$repo_name" == "moos-ivp" ]]; then
        vecho "Skipping repeat of moos-ivp ($repo_name)"  5
        return 0
    fi    
    if [ $ALL != "yes" ]; then
        if [ -f ".built_dirs" ]; then
            # determines if the repo was found in .built_dirs
            num=$(grep -Fx -m 1 "$repo" .built_dirs)
            display_num=$num
            if [ -z "$display_num" ]; then
                display_num="0"
            fi
            vecho "num of repo=$repo in .built_dirs is $display_num" 2
            if [ ! -z "$num" ]; then
                echo "      ${repo_name} ${txtgrn} Already built. skipping...${txtrst}" ; continue
            fi
            if [ -d "$repo_name/bin" ]; then
                echo "      ${repo_name} ${txtgrn} Already built. skipping...${txtrst}" ; continue
                echo "$repo_name" >> .built_dirs
            fi
        fi
        # Determines if the repo is used for the job
        if is_in_job $repo_name; then
            echo "      Updating & building $repo_name..."
        else
            echo $txtgry "     $repo_name is not part of this job. Skipping..." $txtrst
            return 0
        fi
    fi
    return 1
}
#  Updates all necesary repos in an repo_links.txt file
handle_repo_links_file() {
    local repo_links_file=$1
    #-------------------------------------------------------
    #  Git clone/git pull/build.sh all dirs in the file
    #-------------------------------------------------------

    # Loop through all repos in the file
    while read -r repo || [[ -n "$repo" ]]
    do
        if [[ $repo == "" ]]; then
            vecho "Skipping blank line... $repo" 10
            continue
        fi
        if [[ -z $repo ]]; then
            vecho "Skipping blank line (v2)... $repo" 10
            continue
        fi
        if [[ -z "${repo// /}" ]]; then
            vecho "Skipping blank line (v3)... $repo" 10
            continue
        fi
        if [[ $repo == \#* ]]; then
            vecho "Skipping comment... $repo" 10
            continue
        fi
        repo_name=$(extract_repo_name $repo)
        if [[ "$repo_name" == "moos-ivp" ]]; then
            vecho "Skipping repeat of moos-ivp ($repo_name)"  5
            continue
        fi   
          
        if [ $ALL != "yes" ]; then
            if [ -f ".built_dirs" ]; then
                # determines if the repo was found in .built_dirs
                num=$(grep -Fx -m 1 "$repo" .built_dirs)
                display_num=$num
                if [ -z "$display_num" ]; then
                    display_num="0"
                fi
                vecho "num of repo=$repo in .built_dirs is $display_num" 2
                if [ ! -z "$num" ]; then
                    echo "      ${repo_name} ${txtgrn} Already built. skipping...${txtrst}" ; continue
                fi
                if [ -d "$repo_name/bin" ]; then
                    echo "      ${repo_name} ${txtgrn} Already built. skipping...${txtrst}" ; continue
                    echo "$repo_name" >> .built_dirs
                fi
            fi
            # Determines if the repo is used for the job
            if is_in_job $repo_name; then
                echo "      Updating & building $repo_name..."
            else
                echo $txtgry "     $repo_name is not part of this job. Skipping..." $txtrst
                continue
            fi
        fi


        #-------------------------------------------------------
        #  Part 4b: Handle mutliple types of repos: git
        if [[ $repo = *.git ]]; then
            vecho "  $repo_name is a git repo" 2

            if [ -d "moos-dirs/$repo_name" ]; then
                echo -n "        Updating..."
                cd moos-dirs/$repo_name
                gpull $repo $repo_links_file
                cd ../..
            else
                echo "   Cloning $repo_name..."
                cd moos-dirs
                git clone "$repo" &> /dev/null
                # if ! timeout $PROMPT_TIMEOUT git clone "$repo" &> /dev/null; then
                #     vexit "git clone on $repo timed out, check $repo_links_file" 2
                # fi
                # check that it worked
                if [ $? -ne 0 ]; then
                    vexit "git clone on $repo failed, check $repo_links_file" 2
                fi
                cd ../
            fi
        #-------------------------------------------------------
        #  Part 4b: Handle mutliple types of repos: local repos
        elif [[ "$repo" == "~/"* ]] || [[ "$repo" == "/"* ]]; then

            # add link if it does not exist
            if [ ! -L "moos-dirs/${repo_name}" ]; then
                if [[ "$repo" == "~/"* ]]; then
                    repo="${repo/#\~/$HOME}"
                fi
                echo "   linking with: ln -s \"$repo\" \"moos-dirs/${repo_name}\""
                ln -s "$repo" "moos-dirs/${repo_name}"
            fi

            echo -n "        Updating..."
            cd moos-dirs/$repo_name ||  (echo $txtred "$0 Error unable to cd moos-dirs/$repo_name exiting..."; exit 1)
            if [ -f ".git" ]; then
                gpull $repo $repo_links_file
            elif [ -f ".svn" ]; then
                svnup $repo $repo_links_file
            fi
            echo $txtgrn " updated sucessfully" $txtrst
            cd ../..
        else
            vexit "$repo is not a valid repo" 2
        fi
        
        #-------------------------------------------------------
        #  Part 4c: build the repo
        cd moos-dirs/"$repo_name" ||  (vexit "unable to cd moos-dirs/$repo_name " 2)
        echo -n "        Building..."
        if [[ $QUIET == "yes" ]]; then
            ./$script "${FLOW_DOWN_ARGS}" > /dev/null 2>&1
        else
            ./$script "${FLOW_DOWN_ARGS}"
        fi

        if [ $? -ne 0 ]; then
            vexit "build failed on $repo_name with exit code $?" 3
        fi
        wait
        echo $txtgrn " built sucessfully" $txtrst
        cd - > /dev/null || exit 1
        echo "$repo" >> .built_dirs
    done < "$repo_links_file"
}


#-------------------------------------------------------
#  Part 5: Add cmake to path if not already there
#-------------------------------------------------------
if type cmake > /dev/null 2>&1; then
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
if type cmake > /dev/null 2>&1; then
    true
else
    vexit "make not found. Please fix and try again" 1
fi



#-------------------------------------------------------
#  Part 6: Loop through and finds each repo_links.txt file
#-------------------------------------------------------
handle_repo_links_file "repo_links.txt"
# loop through all repo_links.txt files in the JOB_DIR and all of its parent directories
SEARCH_DIR=$(dirname $JOB_FILE)
SEARCH_DIR_BASE="${SEARCH_DIR%%/*}"
vecho "Starting search with $SEARCH_DIR, going to $SEARCH_DIR_BASE" 1
while [[ "$SEARCH_DIR" != "$SEARCH_DIR_BASE" ]]; do
    vecho "Searching for repo_links.txt in $SEARCH_DIR" 3
    if [ -f "$SEARCH_DIR/repo_links.txt" ]; then
        vecho "     Found $SEARCH_DIR/repo_links.txt" 1
        handle_repo_links_file "$SEARCH_DIR/repo_links.txt"
    else
        vecho "     Did not find a repo_links.txt in $SEARCH_DIR" 5
    fi
    SEARCH_DIR=$(dirname $SEARCH_DIR)
done


#-------------------------------------------------------
#  Part 7: Check that every required repo has been updated
#-------------------------------------------------------
# Check that all repos have been built
for repo in "${VEHICLE_REPOS[@]}"
do
    if has_built_repo $repo ; then
        vexit "has not built $repo" 1
    fi
done
for repo in "${EXTRA_REPOS[@]}"
do
    if has_built_repo $repo ; then
        vexit "has not built $repo" 1
    fi
done
for repo in "{$EXTRA_LIB_REPOS[@]}"
do
    if has_built_repo $repo ; then
        vexit "has not built $repo" 1
    fi
done
for repo in "{$EXTRA_BIN_REPOS[@]}"
do
    if has_built_repo $repo ; then
        vexit "has not built $repo" 1
    fi
done
if has_built_repo moos-ivp ; then
        vexit "has not built moos-ivp" 1
fi


