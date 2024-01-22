#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME="encrypt_file.sh"
VERBOSE=0
txtrst=$(tput sgr0)    # Reset
txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtblu=$(tput setaf 4) # Blue
txtgry=$(tput setaf 8) # Grey
# vecho "message" level_int
vecho() { if [[ "$VERBOSE" -ge "$2" || -z "$2" ]]; then echo $(tput setaf 245)"$ME: $1" $txtrst; fi; }
vexit() {
    echo $txtred"$ME: Error $1. Exit Code $2" $txtrst
    exit "$2"
}

#-------------------------------------------------------
#  Part 1: Check for and handle command-line arguments
#-------------------------------------------------------
for ARGI; do
    ALL_ARGS+=$ARGI" "
    if [ "${ARGI}" = "--help" -o "${ARGI}" = "-h" ]; then
        echo "$ME.sh  [FILE] --output=output_filename"
        echo "                                                          "
        echo " This is a script used to encrypt/decrypt files/dirs "
        echo "                                                          "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        # echo " --input=       file or dir to be encrypted "
        echo " --output=       "
        exit 0
    elif [[ "${ARGI}" == "--output="* ]]; then
        OUTPUT="${ARGI#*=}"
    else
        INPUT="${ARGI}"
    fi
done

# Get password from file
PASSWORD=$(head -n 1 ${CARLO_DIR_LOCATION}/.password)


INPUT="$(realpath $INPUT)"
vecho "INPUT = ${INPUT}" 3

# Check for input file
if [[ -z $INPUT ]]; then
    vexit " No input file or dir found. Use -h or --help for help with this script" 1
fi




#######################################################
# Encrypt or decrypt based on file extension
#######################################################
#       DECRYPT
if [[ $INPUT = *".enc" ]]; then
    echo "Decrypting..."
    INPUT_STRIPPED="${INPUT%.enc}"
    if [[ -z $OUTPUT ]]; then
        # remove .enc from output
        OUTPUT="$INPUT_STRIPPED"
    fi
    # decrypt
    openssl enc -pbkdf2 -d -aes-256-cbc -in "$INPUT" -out "$INPUT_STRIPPED" -pass pass:"$PASSWORD"
    vecho "Decrypted!" 1
    if [[ $? -ne 0 ]]; then
        vexit "error decrypting input " 4
    fi
    vecho "Removing $INPUT" 1
    # rm "$INPUT"

    # If it's a directory, decompress
    if [[ $INPUT_STRIPPED = *".tar.gz" ]]; then

        if [[ $OUTPUT = *".tar.gz" ]]; then
            # Remove .tar.gz from output
            OUTPUT="${OUTPUT%.tar.gz}"
        fi
        vecho "Decompressing $INPUT_STRIPPED..." 2
        mkdir -p $OUTPUT
        tar -P -xzf "$INPUT_STRIPPED" -C $OUTPUT #2> /dev/null
        if [[ $? -ne 0 ]]; then
            vexit "error decompressing file" 5
        fi
        vecho "Decompressed $INPUT_STRIPPED to $OUTPUT. Removing $INPUT_STRIPPED" 1
        rm "$INPUT_STRIPPED"
    else
        vecho "not compressed, good to go" 1
        true
    fi

#######################################################
# Encrypt or decrypt based on file extension
#######################################################
#       ENCRYPT
else

    # If it's a directory, compress it first
    if [[ -d $INPUT ]]; then
        # Compress first
        old_pwd=$(pwd)
        base_input=$(basename $INPUT)
        dirname_input=$(dirname $INPUT)
        cd $dirname_input
        vecho "in dir $(pwd)" 2
        vecho "Input is a directory. Compressing..." 1
        vecho "tar -czf \"${base_input}.tar.gz\" $base_input " 2
        tar        -czf  "${base_input}.tar.gz"  $base_input #"$base_input" -C $base_input #2> /dev/null
        if [[ $? -ne 0 ]]; then
            vexit " compressing file" 2
        fi
        # rm -rfd "$base_input"
        cd $old_pwd
        INPUT="${INPUT}.tar.gz"
        vecho "Now zipped to input file: $INPUT" 1
    elif [[ -f $INPUT ]]; then
        # echo "Input is a file. Good to go."
        true
    else
        vecho "Input is not a file or directory" 1
    fi

   if [[ -z $OUTPUT ]]; then
        # add .enc to output
        OUTPUT="${INPUT}.enc"
    fi
    vecho "Encrypting..." 1
 
    # encrypt
    openssl enc -pbkdf2 -aes-256-cbc -salt -in "$INPUT" -out "$OUTPUT" -pass pass:"$PASSWORD"
    if [[ $? -ne 0 ]]; then
        vexit "error encrypting input " 6
    fi
    # rm "$INPUT"

fi

vecho "Output: $OUTPUT" 1
exit 0
