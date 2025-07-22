@echo off
REM =============================================
REM Script: addline.bat
REM Description: Adds a truly empty line to every file
REM              in a specified folder (recursive)
REM              and commits each file individually.
REM Usage: 
REM   1. addline.bat             --> runs in current folder
REM   2. addline.bat path\to\dir --> runs in specified folder
REM =============================================

REM Use current directory if no argument is given
set "TARGET_FOLDER=%~1"
if "%TARGET_FOLDER%"=="" set "TARGET_FOLDER=%CD%"

REM Check if the folder exists
if not exist "%TARGET_FOLDER%" (
    echo Error: Folder "%TARGET_FOLDER%" does not exist.
    exit /b 1
)

echo Adding truly empty lines to all files in: "%TARGET_FOLDER%" and subfolders

REM Change to target directory
pushd "%TARGET_FOLDER%"

REM Recursively loop through all files in all subfolders
for /r %%f in (*.*) do (
    >>"%%f" echo(
    echo Modified : %%f

    git add "%%f"
    git commit -m "Added and modified -- %%~nxf"
    echo Committed: %%f
)

REM Return to original directory
popd

echo Done!


