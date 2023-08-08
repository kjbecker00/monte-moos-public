#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 07/18/2023
# Script: host_scripts/update_job_dirs.sh
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
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo ${txtgry}"$ME: $1" ${txtgry}; fi }
vexit() { echo $txtred"$ME: Error $1. Exit Code $2" $txtrst; exit "$2" ; }

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]                                       "
        echo "Updates the job_dirs in /home/web/monte "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0;
    elif [[ "${ARGI}" = "foo" || "${ARGI}" = "bar" ]]; then
        FOOBAR=0
    elif [[ "${ARGI}" =~ "--verbose" || "${ARGI}" =~ "-v" ]]; then
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

for item in "job_dirs"/*; do
    
    vecho "  item=$item" 1
    if [ ! -d $item ]; then
        vecho "    $item is not a directory. continuing..." 1
        continue
    fi


    #  copy to backup
    #- - - - - - - - - - - - - - - - - - - - - - - -
    JOB_DIR="${item#job_dirs/}"

    vecho "  copying to backup job_dir" 3
    cp -rp "job_dirs/$JOB_DIR" "job_dirs/backup_$JOB_DIR"
    vecho "cp -rp job_dirs/$JOB_DIR job_dirs/backup_$JOB_DIR" 2
            EXIT_CODE=$?
            [ $EXIT_CODE -eq 0 ]    || { vexit "failed to run cp -rp \"job_dirs/$JOB_DIR\" \"backup_$JOB_DIR\" returned exit code: $EXIT_CODE" 3; }
    


    #  encrypt
    #- - - - - - - - - - - - - - - - - - - - - - - -
    ENCRYPTED_JOB_DIR="/home/web/monte/clients/job_dirs/$JOB_DIR.tar.gz.enc"
    vecho "  encrypting job_dir with ./encrypt_file.sh job_dirs/$JOB_DIR" 3
    ./encrypt_file.sh "job_dirs/$JOB_DIR" > /dev/null
    EXIT_CODE=$?
    [ $EXIT_CODE -eq 0 ]    || { vexit "running ./encrypt_file.sh returned exit code: $EXIT_CODE" 4; }
    if [ ! -d "job_dirs/backup_$JOB_DIR" ]; then
        vexit "job_dirs/$JOB_DIR does not exist" 5
    fi


    #  restore origional from backup
    #- - - - - - - - - - - - - - - - - - - - - - - -
    mv "job_dirs/backup_$JOB_DIR" "job_dirs/$JOB_DIR"
    vecho "mv job_dirs/backup_$JOB_DIR job_dirs/$JOB_DIR" 3
    EXIT_CODE=$?
    [ $EXIT_CODE -eq 0 ]    || { vexit "mv job_dirs/backup_$JOB_DIR  job_dirs/$JOB_DIR returned exit code: $EXIT_CODE" 6; }
    if [ ! -f "job_dirs/${JOB_DIR}.tar.gz.enc" ]; then
        vexit "job_dirs/${JOB_DIR}.tar.gz.enc does not exist" 7
    fi


    #  move encrypted to web
    #- - - - - - - - - - - - - - - - - - - - - - - -
    vecho "   moving encrypted job dir to web directory" 3
    vecho "   using: mv job_dirs/${JOB_DIR}.tar.gz.enc $ENCRYPTED_JOB_DIR" 3
    # mkdir -p "$ENCRYPTED_JOB_DIR"
    mv "job_dirs/${JOB_DIR}.tar.gz.enc" "$ENCRYPTED_JOB_DIR" # "/home/web/monte/clients/job_dirs"
        EXIT_CODE=$?
        [ $EXIT_CODE -eq 0 ]    || { vexit "running mv job_dirs/${JOB_DIR}.tar.gz.enc $ENCRYPTED_JOB_DIR returned exit code: $EXIT_CODE" 8; }

    echo "$txtgrn    $JOB_DIR updated$txtrst"

done
