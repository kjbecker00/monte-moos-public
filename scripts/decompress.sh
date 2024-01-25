#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME="decompress.sh"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  [FILE] "
        echo "                                                          "
        echo " This is a script used to decompress dirs "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        echo " --delete, -d Delete origional                            "
        echo " --overwrite, -o Overwrite existing dir                           "
        exit 0
    elif [ "${ARGI}" = "--delete" -o "${ARGI}" = "-d" ]; then
        DELETE="yes"
    elif [ "${ARGI}" = "--overwrite" -o "${ARGI}" = "-o" ]; then
        OVERWRITE="yes"
    else
        INPUT="${ARGI}"
    fi
done

VERBOSE=10

#-------------------------------------------------------
#  Part 2: Check arguments
#-------------------------------------------------------

# INPUT="$(realpath $INPUT)"
vecho "INPUT = ${INPUT}" 3
# Check for input file
if [[ ! -f $INPUT ]]; then
    vexit " No input file found. Use -h or --help for help with this script" 1
fi

cd $(dirname $INPUT)
input_basename=$(basename $INPUT)
INPUT_STRIPPED="${input_basename%.tar.gz}"

#-------------------------------------------------------
#  Part 3: Overwrite existing dir
#-------------------------------------------------------
if [[ -d $INPUT_STRIPPED ]]; then
    if [[ $OVERWRITE = "yes" ]]; then
        vecho "Removing existing dir $INPUT_STRIPPED" 2
        rm -rf $INPUT_STRIPPED
    else
        vexit "Directory $INPUT_STRIPPED already exists. Use -o or --overwrite to overwrite" 2
    fi
fi

#-------------------------------------------------------
#  Part 4: Compress
#-------------------------------------------------------
vecho "Decompressing $INPUT..." 2
tar -xzf "$input_basename" #-C "$basename"
if [[ $? -ne 0 ]]; then
    vexit "error decompressing file" 5
fi

#-------------------------------------------------------
#  Part 5: Delete origional
#-------------------------------------------------------
if [[ $DELETE = "yes" ]]; then
    rm ${INPUT_STRIPPED}.tar.gz
fi

exit 0
