#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 07/18/2023
# Script: host_scripts/update_repo_links.sh
#--------------------------------------------------------------
# Part 1: Convenience functions
#--------------------------------------------------------------
ME=$(basename "$0")
VERBOSE=0
txtrst=$(tput sgr0)       # Reset
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtltblu=$(tput setaf 75) # Light Blue
txtgry=$(tput setaf 8)    # Grey
txtul=$(tput smul)        # Underline
txtul=$(tput bold)        # Bold
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtgry}; fi; }
vexit() {
    echo $txtred"$ME: Error $1. Exit Code $2" $txtrst
    exit "$2"
}

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]                                        "
        echo "Updates the repo_links.txt.enc file in /home/web/monte"
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" = "foo" || "${ARGI}" = "bar" ]]; then
        FOOBAR=0
    elif [[ "${ARGI}" =~ "--verbose=" || "${ARGI}" =~ "-v=" ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        vexit "Bad Arg: $ARGI" 1
    fi
done

#--------------------------------------------------------------
#  Part 3:
#--------------------------------------------------------------

# encrypt and copy repo_links.txt
cp repo_links.txt backup_repo_links.txt
./scripts/encrypt_file.sh repo_links.txt >/dev/null
mv repo_links.txt.enc /home/web/monte/clients
mv backup_repo_links.txt repo_links.txt

echo "$txtgrn    Repo links updated$txtrst"
