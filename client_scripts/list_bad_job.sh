#!/bin/bash
#--------------------------------------------------------------
# Author: Kevin Becker
# Date: 08/30/2023
# Script: list_bad_job.sh
#--------------------------------------------------------------
# Part 1: Convenience functions, set variables
#--------------------------------------------------------------
ME="list_bad_job.sh"
JOB=""
DELETE=""

source "/${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh"

#--------------------------------------------------------------
#  Part 2: Check for and handle command-line arguments
#--------------------------------------------------------------
for ARGI; do
    if [[ "${ARGI}" = "--help" || "${ARGI}" = "-h" ]]; then
        echo "$ME: [OPTIONS]   [JOB]"
        echo "                                                          "
        echo "Lists a job as a bad_job by writing to bad_jobs.txt cache.       "
        echo " These jobs, regardless of the argumnets, will be skipped "
        echo " over by the run_next.sh script. This file also gets sent "
        echo " to the host, so it can distribute jobs more intelligently."
        echo "                                                          "
        echo "Options:                                              "
        echo "  --help, -h                                          "
        echo "    Display this help message                         "
        echo "  --delete, -d                                        "
        echo "    delete the bad_jobs.txt file on the host          "
        echo "  --verbose=num, -v=num or --verbose, -v              "
        echo "    Set verbosity                                     "
        exit 0
    elif [[ "${ARGI}" = "--delete" || "${ARGI}" = "-d" ]]; then
        DELETE="yes"
    elif [[ "${ARGI}" == "--verbose"* || "${ARGI}" == "-v"* ]]; then
        if [[ "${ARGI}" = "--verbose" || "${ARGI}" = "-v" ]]; then
            VERBOSE=1
        else
            VERBOSE="${ARGI#*=}"
        fi
    else
        if [ -z $JOB ]; then
            JOB="$ARGI"
        else
            vexit "Bad Arg: $ARGI" 1
        fi
    fi
done

#--------------------------------------------------------------
#  Part 3: Write to bad_jobs.txt
#--------------------------------------------------------------
if [[ "${DELETE}" != "yes" ]]; then
    echo "$JOB" >>"${CARLO_DIR_LOCATION}"/bad_jobs.txt
    "${MONTE_MOOS_BASE_DIR}"/scripts/send2host.sh "${CARLO_DIR_LOCATION}/bad_jobs.txt" "${MONTE_MOOS_HOST_RECIEVE_DIR}/clients/bad_jobs/${MYNAME}.txt"
else
    [[ -f "${CARLO_DIR_LOCATION}/bad_jobs.txt" ]] && { rm -f "${CARLO_DIR_LOCATION}/bad_jobs.txt"; }
    "${MONTE_MOOS_BASE_DIR}"/scripts/send2host.sh "${MONTE_MOOS_HOST_RECIEVE_DIR}/clients/bad_jobs/${MYNAME}.txt" --delete
    vecho "Delete bad_jobs.txt file" 1
fi
