#!/bin/bash
# Kevin Becker, May 26 2023
# Script used to encrypt/decrypt files

ME=$(basename "$0")
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
        echo "$ME.sh  [FILE]"
        echo " This is a script used to encrypt/decrypt files/dirs "
        echo "Options:                                                  "
        echo " --help, -h Show this help message                        "
        # echo " --input=       file or dir to be encrypted "
        echo " --output=       "
        exit 0
    elif [[ "${ARGI}" =~ "--output=" ]]; then
        OUTPUT="${ARGI#*=}"
    else
        INPUT="${ARGI}"
    fi
done

# Get password from file
PASSWORD=$(head -n 1 .password)

# Check for input file
if [[ -z $INPUT ]]; then
    vexit " No input file or dir found. Use -h or --help for help with this script" 1
fi

# If it's a directory, compress it first
if [[ -d $INPUT ]]; then
    # Compress first
    echo "Input is a directory. Compressing..."
    tar -czf "${INPUT}.tar.gz" "$INPUT"
    if [[ $? -ne 0 ]]; then
        vexit "error compressing file" 2
    fi
    rm -rfd "$INPUT"
    INPUT="${INPUT}.tar.gz"
elif [[ -f $INPUT ]]; then
    # echo "Input is a file. Good to go."
    true
else
    vecho "Input is not a file or directory" 1
fi


#######################################################
# Encrypt or decrypt based on file extension
#######################################################
#       DECRYPT
if [[ $INPUT = *".enc" ]]; then
    echo "Decrypting..."
    INPUT_STRIPPED="${INPUT%.*}"
    if [[ -z $OUTPUT ]]; then
        # remove .enc from output
        OUTPUT="$INPUT_STRIPPED"
    fi
    # decrypt
    openssl enc -pbkdf2 -d -aes-256-cbc -in "$INPUT" -out "$OUTPUT" -pass pass:"$PASSWORD"
    vecho "Decrypted!" 1
    if [[ $? -ne 0 ]]; then
        vexit "error decrypting input " 4
    fi
    rm "$INPUT"

    # If it's a directory, decompress
    if [[ $INPUT_STRIPPED = *".tar.gz" ]]; then
        echo "Decompressing..."
        tar -xzf "$OUTPUT"
        if [[ $? -ne 0 ]]; then
            vexit "error decompressing file" 5
        fi
        rm "$OUTPUT"
    else
        vecho "not compressed, good to go" 1
        true
    fi

#######################################################
# Encrypt or decrypt based on file extension
#######################################################
#       ENCRYPT
else
    echo "Encrypting..."
    if [[ -z $OUTPUT ]]; then
        # add .enc to output
        OUTPUT="${INPUT}.enc"
    fi
    # encrypt
    openssl enc -pbkdf2 -aes-256-cbc -salt -in "$INPUT" -out "$OUTPUT" -pass pass:"$PASSWORD"
    if [[ $? -ne 0 ]]; then
        vexit "error encrypting input " 6
    fi
    rm "$INPUT"

fi

exit 0
