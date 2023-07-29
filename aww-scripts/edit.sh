#!/bin/bash

# Save the current directory
original_dir=$(pwd)

# Change the directory to the location of this script
cd "$(dirname "$0")"

# Open Visual Studio Code in the script's parent directory
code .

# Change back to the original directory
cd "$original_dir"




