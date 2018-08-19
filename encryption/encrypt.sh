#!/bin/bash -e

#*****************************************************************************
# encrypt.sh
# modified: 15/06/2017
#
#
# Script encrypts or decrypts file using a hybrid RSA-AES approach
# A random key is generated to use with AES encryption. This key is then 
# encrypted using RSA (public key for encryption; private for decryption) 
#
# Run like:
# ./encrypt.sh [-?] [-i <input_file> -k <keyfile> [-o <output_file>] [-d] [-K]]"
#
# To [ Decrypt ] run the script with decryption parameter, (RSA key in lastpass) e.g.:
# ./encrypt.sh -k private_RSA_key -i shared--2017-05-10_16-23.sql.gz.tar.gz -d
#
# To [ Encrypt ] eg:
# ./encrypt.sh -k generatedpublickey.pem -i dbdump.sql"
#
# To create a public and private keypair (only needed once):
# ssh-keygen -b 4096 -t rsa -f <NameOfOutputFile>
# openssl rsa -in <NameOfOutputFile> -pubout > <NameOfPublicKey>.pem
#******************************************************************************

#*****************************************************************************
# function   : constants()
# Description: Define some global variables that will be used throughout the script
function constants()
{
  ENCRYPTION=true
  GENERATED_KEY="randomkey.txt"
  INPUT_FILE="inputfile.txt"
  OUTPUT_FILE="decrypted_output.txt"
  OUTPUT_DIR="./"
  KEY="keyname.pem" # Path to public or private key
  KEEP_ORIGINAL=false
}

#*****************************************************************************
# function   : usage()
# Description: Show info to the user how this script should be executed
function usage()
{
  echo
  echo
  echo "USAGE: "
  echo "  encrypt.sh [-?] [-i <input_file> -k <keyfile> [-o <output_file>] [-d] [-K]]"
  echo
  echo "OPTIONS:"
  echo "  -d  Decrypt (Encrypt by default)"
  echo "  -k  <keyfilepath> (Path to public or private key respectively)"
  echo "  -i  <inputFileName> (Name for the file to be encrypted)"
  echo "  -o  <outputFileName> (Name for the file after encryption)"
  echo "  -K  To keep the original file (Removed by default) "
  echo "  -?  This usage information"
  echo
  echo
  exit $E_OPTERROR    # Exit and explain usage, if no argument(s) given.
}

#*****************************************************************************
# function   : initialize()
# Description: Check all parameters and all files
function initialize()
{
  # Check if files exist
  if [ ! -f "$KEY" ]; then
    echo "/!\\ Encryption key does not exist"
    usage;
  elif [ ! -f "$INPUT_FILE" ]; then
    echo "/!\\ The file to be (d)e(n)crypted does not exist"
    usage;
  fi

  if [ "$OUTPUT_FILE" == "decrypted_output.txt" ] && [ $ENCRYPTION == true ]; then
    OUTPUT_FILE="$INPUT_FILE.tar.gz"
  elif [ "$OUTPUT_FILE" == "decrypted_output.txt" ] && [ $ENCRYPTION == false ] && [ ${INPUT_FILE: -7} == ".tar.gz" ]; then
  	OUTPUT_FILE="${INPUT_FILE/.tar.gz/}"
  fi
  OUTPUT_DIR=$( dirname $INPUT_FILE )
}

#*****************************************************************************
# function   : encryption()
# Description: Encrypts a given file using an AES-RSA hybrid
function encryption()
{
  # Generate random key
  openssl rand -base64 32 > $OUTPUT_DIR/$GENERATED_KEY
  # Encrypt file using AES with random key
  openssl enc -aes-256-cbc -salt -in $INPUT_FILE -out  "$INPUT_FILE.enc" -pass file:"$OUTPUT_DIR/$GENERATED_KEY"
  # Encrypt random key using RSA
  openssl rsautl -encrypt -inkey $KEY -pubin -in $OUTPUT_DIR/$GENERATED_KEY -out "$OUTPUT_DIR/$GENERATED_KEY.enc"

  # Zip encrypted key and file and remove files
  tar cvzf $OUTPUT_FILE -C $OUTPUT_DIR $( basename $INPUT_FILE.enc ) $GENERATED_KEY.enc
  rm $OUTPUT_DIR/$GENERATED_KEY*
  rm $INPUT_FILE.enc
  if [ $KEEP_ORIGINAL == false ]; then
    rm $INPUT_FILE
  fi
}

#*****************************************************************************
# function   : decryption()
# Description: Decrypts a given file using an AES-RSA hybrid
function decryption()
{
  # Unpack to a tmp dir to reduce risk of overwriting and ease the removal step
  tmpdir="$OUTPUT_DIR/unpackedtmp"
  mkdir $tmpdir
  tar xvzf $INPUT_FILE -C $tmpdir
  if [[ $( ls $tmpdir/ | grep .enc | wc -l) -lt 2 ]] || [[ $( ls $tmpdir/ | grep .enc | wc -l) -gt 2 ]]; then
  	echo "/!\\ Unable to unzip. Zipped file contains too many or to few encrypted files"
  	echo "Expected: 1 (encrypted) decryption key and 1 encrypted file"
  	usage;
  fi
  ENCRYPTED_KEY=$( ls $tmpdir/ | grep .enc | grep key )

  # Decrypt random key using RSA
  openssl rsautl -decrypt -inkey $KEY -in "$tmpdir/$ENCRYPTED_KEY" -out "$tmpdir/$GENERATED_KEY"
  rm "$tmpdir/$ENCRYPTED_KEY"
  # Decrypt file using AES
  openssl enc -d -aes-256-cbc -in "$tmpdir/$( ls $tmpdir/ | grep .enc )" -out $OUTPUT_FILE -pass file:"$tmpdir/$GENERATED_KEY"

  # Remove unpacked files and decrypted random key
  rm -rf $tmpdir
  if [ $KEEP_ORIGINAL == false ]; then
    rm $INPUT_FILE
  fi
}

#*****************************************************************************
# MAIN PROGRAM
# Process arguments
  constants;

  while [ "$1" != "" ]; do
    case $1 in
      -d | --decrypt )  ENCRYPTION=false;;
      -K | --keep )     KEEP_ORIGINAL=true;;
      -k | --key )      shift
                        KEY=$1;;
      -i | --input )    shift
                        INPUT_FILE=$1;;
      -o | --output )   shift
                        OUTPUT_FILE=$1;;
      -h | --help )     usage; exit 0;;
      ?  )              usage; exit 0;;
      *  )
        echo
        echo "Unimplemented option chosen"
        usage
    esac
    shift
  done

  initialize;

 
  if [ $ENCRYPTION == true ]; then
    echo "Processing encryption"
    encryption;
    echo "File encrypted to $OUTPUT_FILE"
  else
    echo "Processing decryption"
  	decryption;
    echo "File decrypted to $OUTPUT_FILE"
  fi
  
