#!/usr/bin/env bash

# combine all the arguments into a single string
# and pass it to git commit -am

message="$*"

# if message is empty, set it to "update currentDate"
if [ -z "$message" ]; then
    message="update $(date)"
fi

git add --all
git commit -am "$message"
git pull
git push
