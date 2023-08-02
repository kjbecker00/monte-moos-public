#!/bin/bash
# Kevin Becker, May 26 2023
#-------------------------------------------------------
#  Part 0: Initalize the variables
#-------------------------------------------------------

# build script name (indluce any flags here or as flow-down args)
script="build.sh"
repo_links="repo_links.txt"
# args to get passed on to "script"
FLOW_DOWN_ARGS=""
QUIET="yes" 
ALL="no"
PROMPT_TIMEOUT=20
ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)    # Reset                       
txtred=$(tput setaf 1) # Red                        
txtgrn=$(tput setaf 2) # Green  
txtylw=$(tput setaf 3) # Yellow                   
txtblu=$(tput setaf 4) # Blue                     
txtgry=$(tput setaf 8) # Grey                             
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtrst}; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }


is_in_job() {
    local this_repo="${1}"
    if [[ "$SHORE_REPO" == "$this_repo" ]]; then
        return 0
    elif [[ "${VEHICLE_REPOS[@]}" =~ "$this_repo" ]]; then
        return 0
    elif [[ "${EXTRA_REPOS[@]}" =~ "$this_repo" ]]; then
        return 0
    fi
    vecho "      $repo_name is not part of this job" 1
    return 1
}

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

gpull() {
    local repo=$1
    local repo_links_file=$2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        git pull &> /dev/null
    else
        if ! timeout $PROMPT_TIMEOUT git pull &> /dev/null; then
            if [ -z $repo_links_file ]; then
                echo "    ${txtylw}Warning: git pull on $repo timed out. Continuing..."
            else 
                echo ""
                echo "    ${txtylw}Warning: git pull on $repo failed, check $repo_links_file ${txtrst}" 
            fi
        fi
    fi
}


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
                if [ $? -ne 0 ]; then
                    echo ""
                    echo "    ${txtylw}Warning: git pull on $repo failed, check $repo_links_file ${txtrst}" 
                fi
                echo $txtgrn " updated sucessfully" $txtrst
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
                if [ $? -ne 0 ]; then
                    echo ""
                    echo "    ${txtylw}Warning: git pull on $repo failed, check $repo_links_file ${txtrst}" 
                fi
            elif [ -f ".svn" ]; then
                svn up &> /dev/null
                # if ! timeout $PROMPT_TIMEOUT svn up &> /dev/null; then
                #     vexit "svn up on $repo timed out, check $repo_links_file" 2
                # fi
                # check that it worked
                if [ $? -ne 0 ]; then
                    echo "    ${txtylw}Warning: svn up on $repo failed, check $repo_links_file" 2
                fi
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
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh [OPTIONS] "
        echo "  Updates and builds moos-dirs"
        echo "Options: " 
        echo " --help, -h    Show this help message " 
        echo " --job_file=    set the name of the job file (only updates dirs that apply to this job) " 
        echo " --all, -a      update everything it has a repo_links.txt for" 
        echo " All other arguments will flow down to the build script (e.g. -j8 for 8 cores)"
        exit 0;
    elif [[ "${ARGI}" =~ "--job_file=" ]]; then
        JOB_FILE="${ARGI#*=}"
    elif [ "${ARGI}" = "--all" -o "${ARGI}" = "-a" ] ; then
	    ALL="yes"
    else 
        FLOW_DOWN_ARGS+="${ARGI} "
    fi
done

txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey

#-------------------------------------------------------
#  Part 2: Source Job File
#-------------------------------------------------------
if [ $ALL = "yes" ]; then
    echo $txtblu $(tput bold) "Updating all repos in $repo_links" $txtrst
else
    . "$JOB_FILE"
    if [[ $? -ne 0 ]]; then
        vexit "Sourcing job file yeilded non-zero exit code" 4
    fi
fi

#-------------------------------------------------------
#  Part 3: Add cmake to path if not already there
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
#  Part 3: Git clone/git pull/build.sh all dirs
#           base/default dirs to update
#-------------------------------------------------------
# Attempts to link moos-ivp to this directory
mkdir -p moos-dirs
if [ ! -L "moos-dirs/moos-ivp" ]; then
    ln -s ~/moos-ivp moos-dirs/moos-ivp
fi

if [ ! -f ".built_dirs" ]; then
    touch .built_dirs
fi


# update monte-moos repo
if ! grep -qx "monte-moos" .built_dirs; then
    gpull "monte-moos"
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
      echo $txtylw"    ${txtylw}Warning: git pull on monte-moos exited with code: $EXIT_CODE. Ignoring and continuing..."$txtrst
    fi
    echo monte-moos >> .built_dirs
fi

# update moos-ivp
if ! grep -qx "moos-ivp" .built_dirs; then
    cd moos-dirs/moos-ivp > /dev/null
    svn up &> /dev/null
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
      echo "    ${txtylw}Warning: svn up on moos-ivp failed with $EXIT_CODE" 1
    fi
    cd - > /dev/null
    echo moos-ivp >> .built_dirs
fi


#-------------------------------------------------------
#  Part 4: Update the repos from all repo_links.txt files
#-------------------------------------------------------
handle_repo_links_file "repo_links.txt"

# loop through all repo_links.txt files in the JOB_DIR and all of its parent directories
SEARCH_DIR=$(dirname $JOB_FILE)
SEARCH_DIR_BASE="${SEARCH_DIR%%/*}"
vecho "Starting search with $SEARCH_DIR, going to $SEARCH_DIR_BASE" 4
while [[ "$SEARCH_DIR" != "$SEARCH_DIR_BASE" ]]; do
    vecho "Searching for repo_links.txt in $SEARCH_DIR" 3
    if [ -f "$SEARCH_DIR/repo_links.txt" ]; then
        vecho "     Found $SEARCH_DIR/repo_links.txt" 2
        handle_repo_links_file "$SEARCH_DIR/repo_links.txt"
    else
        vecho "     Did not find a repo_links.txt in $SEARCH_DIR" 5
    fi
    SEARCH_DIR=$(dirname $SEARCH_DIR)
done


