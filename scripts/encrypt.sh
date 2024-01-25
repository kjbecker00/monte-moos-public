#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME="encrypt.sh"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  [FILE] "
        echo "                                                          "
        echo " This is a script used to encrypt files "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --password=      For a custom password.                  "
        echo " --delete, -d Delete origional                            "
        echo " --overwrite, -o Overwrite existing dir                           "
        exit 0
    elif [ "${ARGI}" = "--delete" -o "${ARGI}" = "-d" ]; then
        DELETE="yes"
    elif [ "${ARGI}" = "--overwrite" -o "${ARGI}" = "-o" ]; then
        OVERWRITE="yes"
    elif [[ "${ARGI}" == "--password="* ]]; then
        PASSWORD="${ARGI#*=}"
    else
        INPUT="${ARGI}"
    fi
done

#-------------------------------------------------------
#  Part 2: Check arguments
#-------------------------------------------------------

INPUT="$(realpath $INPUT)"
vecho "INPUT = ${INPUT}" 3

# Check for input file
if [[ -z $INPUT ]]; then
    vexit " No input file or dir found. Use -h or --help for help with this script" 1
fi
# Check for input file
if [[ -z $PASSWORD ]]; then
    PASSWORD=$(head -n 1 ${CARLO_DIR_LOCATION}/.password)
    # vexit " No password given" 2
fi

#-------------------------------------------------------
#  Part 3: Overwrite existing file
#-------------------------------------------------------
if [[ -f "${INPUT}.enc" ]]; then
    if [[ $OVERWRITE = "yes" ]]; then
        vecho "Removing existing file ${INPUT}.enc" 2
        rm -f ${INPUT}.enc
    else
        vexit "File ${INPUT}.enc already exists. Use -o or --overwrite to overwrite" 2
    fi
fi

#-------------------------------------------------------
#  Part 43: Encrypt
#-------------------------------------------------------
vecho "Encrypting..." 1

# encrypt
openssl enc -pbkdf2 -aes-256-cbc -salt -in "$INPUT" -pass pass:"$PASSWORD" -out "$INPUT".enc
if [[ $? -ne 0 ]]; then
    vexit "error encrypting input " 6
fi

#-------------------------------------------------------
#  Part 5: Delete origional
#-------------------------------------------------------
if [[ $DELETE == "yes" ]]; then
    rm "$INPUT"
fi

vecho "Output: $OUTPUT" 1
exit 0
