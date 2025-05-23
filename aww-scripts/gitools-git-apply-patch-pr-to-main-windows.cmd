@echo off
REM apply_patch.cmd: apply PR branch changes onto main as staged uncommitted
REM Usage: apply_patch.cmd mainBranch prBranch

setlocal enabledelayedexpansion

set "mainBranch=%~1"
set "prBranch=%~2"

git fetch
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

git checkout "%prBranch%"
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

git pull
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

git checkout "%mainBranch%"
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

git pull
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

git diff --binary --merge-base "%mainBranch%" "%prBranch%" | git apply --index
if %ERRORLEVEL% NEQ 0 (
    exit /b %ERRORLEVEL%
)

exit /b 0