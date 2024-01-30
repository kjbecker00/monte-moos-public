#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME="monte_decrypt.sh"

source /"${MONTE_MOOS_BASE_DIR}"/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  [FILE] "
        echo "                                                          "
        echo " This is a script used to decrypt files "
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

INPUT="$(realpath "$INPUT")"
vecho "INPUT = ${INPUT}" 3

# Check for input file
if [[ -z $INPUT ]]; then
    vexit " No input file or dir found. Use -h or --help for help with this script" 1
fi
# Check for input file
if [[ -z $PASSWORD ]]; then
    PASSWORD=$(head -n 1 "${CARLO_DIR_LOCATION}"/.password)
fi

#-------------------------------------------------------
#  Part 3: Overwrite existing file
#-------------------------------------------------------
OUTPUT="${INPUT%.enc}"
if [[ -f "${OUTPUT}" ]]; then
    if [[ $OVERWRITE = "yes" ]]; then
        vecho "Removing existing file ${OUTPUT}" 2
        rm -f "${OUTPUT}"
    else
        vexit "File ${OUTPUT} already exists. Use -o or --overwrite to overwrite" 2
    fi
fi

#-------------------------------------------------------
#  Part 4: Encrypt
#-------------------------------------------------------
vecho "Decrypting..." 1

openssl enc -pbkdf2 -d -aes-256-cbc -in "$INPUT" -pass pass:"$PASSWORD" -out "$OUTPUT"
vecho "Decrypted!" 1
if [[ $? -ne 0 ]]; then
    vexit "error decrypting input " 4
fi

#-------------------------------------------------------
#  Part 5: Delete origional
#-------------------------------------------------------
if [[ $DELETE == "yes" ]]; then
    rm "$INPUT"
fi
exit 0
