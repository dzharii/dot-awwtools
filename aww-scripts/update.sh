#!/bin/bash

# Save the current directory
original_dir=$(pwd)

# Change the directory to the location of this script
cd "$(dirname "$0")"

# Run git pull command to update the local repository with the latest changes from the remote repository
git pull

# Change back to the original directory
cd "$original_dir"