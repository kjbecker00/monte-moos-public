#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME="monte_compress.sh"

source /${MONTE_MOOS_BASE_DIR}/lib/lib_include.sh

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  [FILE] "
        echo "                                                          "
        echo " This is a script used to compress dirs "
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

#-------------------------------------------------------
#  Part 2: Check arguments, cd to dirname fiel
#-------------------------------------------------------

INPUT="$(realpath $INPUT)"
vecho "INPUT = ${INPUT}" 3
if [[ ! -d $INPUT ]]; then
    vexit " No input dir found. Use -h or --help for help with this script" 1
fi

# cd to file dir
base_input=$(basename $INPUT)
cd $(dirname $INPUT)

#-------------------------------------------------------
#  Part 3: Overwrite existing file
#-------------------------------------------------------
if [[ -f "${base_input}.tar.gz" ]]; then
    if [[ $OVERWRITE = "yes" ]]; then
        vecho "Removing existing file ${base_input}.tar.gz" 2
        rm -f ${base_input}.tar.gz
    else
        vexit "File ${base_input}.tar.gz already exists. Use -o or --overwrite to overwrite" 2
    fi
fi

#-------------------------------------------------------
#  Part 4: Compress
#-------------------------------------------------------
vecho "Compressing..." 1
vecho "Input is a directory. Compressing..." 1
vecho "tar -czf \"${base_input}.tar.gz\" $base_input " 2
tar -czf "${base_input}.tar.gz" $base_input #"$base_input" -C $base_input #2> /dev/null
if [[ $? -ne 0 ]]; then
    vexit " compressing file" 2
fi

#-------------------------------------------------------
#  Part 5: Delete origional
#-------------------------------------------------------
if [[ $DELETE = "yes" ]]; then
    rm -rf $INPUT
fi

exit 0
