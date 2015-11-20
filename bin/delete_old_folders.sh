#!/bin/sh

readonly DAYS=$1
readonly DIRECTORY=$2

is_empty() {
    local var=$1
    [ -z $var ]
}

is_directory() {
    local path=$1
    [ -d "$path" ]
}

main() {
    if is_empty $DAYS || is_empty $DIRECTORY; then
	echo "Mandatory parameter(s) not specified (DAYS, DIRECTORY)."
	exit 1
    fi

    if [ $DAYS -lt 1 ]; then
	echo "The DAYS parameter must be greater than 0."
	exit 1
    fi

    if ! is_directory $DIRECTORY; then
	echo "The given path ${DIRECTORY} is not an existing directory."
	exit 1
    fi
    
    echo "Cleaning directory: ${DIRECTORY}"
    find $DIRECTORY -depth -mindepth 1 -maxdepth 1 -type d -mtime +$DAYS -exec rm -rfv '{}' \;
}
main
