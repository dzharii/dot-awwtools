#!/usr/bin/env bash

# check if argument "minutest" is not empty and it is a number
# if not -- exit with error
if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: first argument must be a number of minutes"
    exit 1
fi

sudo shutdown -P +$1