:: Use pushd to change the current directory to the location of this batch file (%~dp0)
pushd %~dp0

:: Open Visual Studio Code in the script's directory
start code .

:: Use popd to return to the original directory
popd

