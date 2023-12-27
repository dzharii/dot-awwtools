:: Use pushd to change the current directory to the location of this batch file (%~dp0)
pushd %~dp0

:: Use call to run the git pull command, which updates your local repository with the latest changes from the remote repository
call git pull

:: Use popd to return to the original directory
popd
