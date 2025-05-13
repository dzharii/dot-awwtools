@echo off
REM apply_patch.cmd: apply PR branch changes onto main as staged uncommitted
REM Usage: apply_patch.cmd mainBranch prBranch

setlocal

set "mainBranch=%~1"
set "prBranch=%~2"

git checkout "%prBranch%"
if ERRORLEVEL 1 (
    exit /b %ERRORLEVEL%
)
git pull
if ERRORLEVEL 1 (
    exit /b %ERRORLEVEL%
)

git checkout "%mainBranch%"
if ERRORLEVEL 1 (
    exit /b %ERRORLEVEL%
)
git pull
if ERRORLEVEL 1 (
    exit /b %ERRORLEVEL%
)

git diff --merge-base "%mainBranch%" "%prBranch%" | git apply --index
if ERRORLEVEL 1 (
    exit /b %ERRORLEVEL%
)

exit /b 0
