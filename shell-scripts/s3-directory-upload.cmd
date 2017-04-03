:: Set up environment
@ECHO OFF

SETLOCAL EnableDelayedExpansion

:: Global paths
SET tempDir=%TEMP%\s3-directory-upload
SET ERROR_FILE=%tempDir%\error.txt

IF NOT EXIST "%tempDir%" MKDIR "%tempDir%"
TYPE NUL > "%ERROR_FILE%"

:: Initialize global variables
SET help=false
SET recurse=true

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int main(string[] args)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main

SET errCode=0

:: Parse arguments
:: If there were any errors then display messages and exit
DEL /F /Q /S "%tempDir%\*" > NUL
CALL :parseArgs %* & IF ERRORLEVEL 1 GOTO Catch

:: If help was requested then show proper usage and exit
IF %help%==true (
    ECHO. > CON
    CALL :showUsage CON true
    GOTO Finally
)

:: Validate the provided directory
:: If there were any errors then display messages and exit
CALL :validateArgs %rootDir% & IF ERRORLEVEL 1 GOTO Catch

:: If everything looks good, then
:: Upload all files in the provided directory to S3, recursively if requested
CALL :uploadFolder %rootDir% 0 & IF ERRORLEVEL 1 GOTO Catch

GOTO Finally

:Catch
TYPE "%ERROR_FILE%" 1>&2
SET errCode=1
GOTO Finally

:Finally
RMDIR /S /Q "%tempDir%"
EXIT /B %errCode%

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void showUsage(string filename, bool extended)
::
:: Writes messages to the provided file
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:showUsage

SETLOCAL EnableDelayedExpansion

SET filename=%1
SET extended=%2

:: Return basic usage
ECHO Usage: s3-directory-upload [options] ^<rootDir^> >> "%filename%"
IF %extended%==false (EXIT /B 0)

:: If the extended description was requested, then return this text
>> "%filename%" (
    ECHO.
    ECHO    rootDir          Path to the directory containing files ^(and folders^) to upload.
    ECHO                     The full paths of these files are used as keys in S3, minus
    ECHO                     the path of this root directory.  Files in all subfolders are
    ECHO                     recursively uploaded also.  So, for example, if the provided 
    ECHO                     directory is 'C:\Users\Derp\data\', and that directory contains
    ECHO                     two files named 'file1.ext' and 'file2.ext', and a subfolder
    ECHO                     named 'Sub\' containing a single file named 'subFile.ext',
    ECHO                     then a total of 3 objects will be uploaded to S3, with keys 
    ECHO                     'file1.ext', 'file2.ext', and 'Sub\subFile.ext'.  This
    ECHO                     recursion can be turned off with the --subfolders option.  File
    ECHO                     and subfolder names must not contain any spaces.
    ECHO.
    ECHO    -b, --bucket     Required.  Name of the AWS S3 bucket to which you are uploading.
    ECHO    -h, --help       Show this help text.
    ECHO        --prefix     An optional prefix to apply to all objects uploaded to S3.  Must
    ECHO                     not contain any spaces.
    ECHO    -p, --profile    Required.  A specific profile from your AWS CLI credential file.
    ECHO                     This profile must have already been created with "aws configure".
    ECHO                     Like with other AWS commands, you can also set the 
    ECHO                     AWS_DEFAULT_PROFILE environment variable beforehand.  Any actual
    ECHO                     value passed to --profile overrides this environment variable.
    ECHO    -s, --subfolders Optional.  Follow this option with 'true' to recursively upload
    ECHO                     files in all subfolders ^(behavior default^).  Follow with 'false'
    ECHO                     to prevent this behavior.
    ECHO.
    ECHO    Options can also be specified with a '/' character.  E.g., '/H' to show help.
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int parseArgs(string[] args)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:parseArgs

SET recurse=true

:: If no arguments were provided then show usage and exit
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" (
    ECHO Error: Missing required arguments>> "%ERROR_FILE%"
    ECHO.>> "%ERROR_FILE%"
    CALL :showUsage "%ERROR_FILE%" false
    EXIT /B 1
)

:loop
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO (SET arg=%%~a)   &:: Remove double quotes
IF "%arg%"=="" GOTO continueParse

:: Parse root directory path
SET good=true
IF "%arg:~0,1%"=="-" (SET good=false)
IF "%arg:~0,1%"=="/" (SET good=false)
IF %good%==true (
    IF DEFINED rootDir (
        ECHO Error: You may provide the path to only one directory with files to upload^^! >> "%ERROR_FILE%"
        EXIT /B 1
    ) ELSE (
        SET rootDir=%arg%
        SHIFT
        GOTO loop
    )
)

:: Parse bucket name
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isBucket=false
SET values=-b /b /B --bucket
FOR %%v IN (%values%) DO IF %arg%==%%v SET isBucket=true
IF %isBucket%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --bucket requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET bucket=!arg!
    SHIFT
    GOTO loop
)

:: Parse help flag
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isHelp=false
SET values=-h /h /H --help /?
FOR %%v IN (%values%) DO IF %arg%==%%v SET isHelp=true
IF %isHelp%==true (
    SET help=true
    SHIFT
    GOTO loop
)

:: Parse object key prefix
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isPrefix=false
SET values=--prefix
FOR %%v IN (%values%) DO IF %arg%==%%v SET isPrefix=true
IF %isPrefix%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --prefix requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET prefix=!arg!
    SHIFT
    GOTO loop
)

:: Parse AWS credentials profile
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isProfile=false
SET values=-p /p /P --profile
FOR %%v IN (%values%) DO IF %arg%==%%v SET isProfile=true
IF %isProfile%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --profile requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET profile=!arg!
    SHIFT
    GOTO loop
)

:: Parse subfolders recurse toggle
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isRecurs=false
SET values=-s /s /S --subfolders
FOR %%v IN (%values%) DO IF %arg%==%%v SET isRecurs=true
IF %isRecurs%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --subfolders requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET recurse=!arg!
    SHIFT
    GOTO loop
)

:: If this arg was invalid...
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
ECHO Error: unrecognized argument "%arg%" >> "%ERROR_FILE%"
EXIT /B 1

GOTO loop

:continueParse

:: If help was requested, then just exit
IF %help%==true (EXIT /B 0)

:: Ensure required arguments were provided
SET valid=true
IF NOT DEFINED rootDir (SET valid=false & ECHO Error: You must provide a path to a directory containing files to upload >> "%ERROR_FILE%")
IF NOT DEFINED bucket (SET valid=false & ECHO Error: You must provide a bucket name (--bucket^) >> "%ERROR_FILE%")

:: Try to set the missing AWS credentials profile with an environment variable
IF NOT DEFINED profile (
    IF DEFINED AWS_DEFAULT_PROFILE (
        SET profile=%AWS_DEFAULT_PROFILE%
    ) ELSE (
        SET valid=false
        ECHO Error: You must provide an AWS CLI credentials profile (--profile^) >> "%ERROR_FILE%"
    )
)

IF %valid%==false EXIT /B 1

:: Unset local vars before exit
SET arg=
SET validArg=
SET valid=
SET result=

SET isBucket=
SET isHelp=
SET isPrefix=
SET isProfile=
SET isRecurs=

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int validatePath()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:validateArgs

:: Remove double quotes from the main directory path
SET rootDir=%~f1
SET rootDir=%rootDir:"=%

:: Make sure the provided path exists
IF NOT EXIST "%rootDir%" (
    ECHO Error: Could not find the path "%rootDir%" >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path is a directory, not a file
IF NOT EXIST "%rootDir%\*" (
    ECHO Error: The provided path must be a directory. >> "%ERROR_FILE%"
    ECHO "%rootDir%" is a file. >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path ends with a slash
SET hasSlash=false
IF "%rootDir:~-1%"=="\" SET hasSlash=true
IF "%rootDir:~-1%"=="/" SET hasSlash=true
IF %hasSlash%==false SET rootDir=%rootDir%\

:: Make sure the prefix ends with a slash
IF NOT "%prefix%"=="" (
  SET hasSlash=false
  IF "%prefix:~-1%"=="\" SET hasSlash=true
  IF "%prefix:~-1%"=="/" SET hasSlash=true
  IF !hasSlash!==false SET prefix=%prefix%\
)

SET hasSlash=

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int uploadFolder(string dirPath, int numIndents, string bucket, string profile, string prefix="", bool recurse=true)
::
:: This function calls itself recursively (if requested) to upload files in all subfolders
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:uploadFolder

SETLOCAL EnableDelayedExpansion

SET uploadErrFile=%tempDir%\uploadErr.txt
TYPE NUL > "%uploadErrFile%"

SET dirPath=%~f1
SET numIndents=%2

:: If there are no files in this directory, then don't bother logging it
SET numFiles=0
FOR %%f IN ("%dirPath%\*") DO SET /A numFiles+=1
IF /I %numFiles% GTR 0 (
    SET str=-
    FOR /L %%I IN (1, 1, %numIndents%) DO SET str= !str!
    ECHO !str!Uploading %numFiles% files from folder "%dirPath%"...
)

:: Upload each file and log progress
SET numErrs=0
FOR %%F IN ("%dirPath%*") DO (
    SET str=  
    FOR /L %%I IN (1, 1, %numIndents%) DO SET str= !str!
    SET key=%%~fF
    SET key=%prefix%!key:%rootDir%=!
    SET key=!key:\=/!
    ECHO !str!   Uploading object: !key!
        
    :: Attempt to upload this file
    aws s3api put-object ^
        --bucket %bucket% ^
        --body "%%F" ^
        --key !key! ^
        --profile %profile% 2> "%uploadErrFile%" 1> NUL     &REM File redirection must occur on same line as last option

    :: If any AWS API errors occurred then log them and continue to the next file
    SET size=0
    FOR /F %%s IN ("%uploadErrFile%") DO SET size=%%~zs
    IF /I !size! GTR 0 (
        ECHO !str!     Failed to upload "%%F"^^!  More details will be provided at the end. > CON
        IF !numErrs!==0 (
            SET /A numErrs+=1
            >> "%ERROR_FILE%" (
                ECHO.
                ECHO Uploads complete.  However, at least one file failed to upload.
                ECHO You can manually re-upload these files using the AWS CLI.
                ECHO Here are some more details:
                ECHO.
            )
        )
        ECHO Upload of file %%~fF failed with error message: >> "%ERROR_FILE%"
        TYPE "%uploadErrFile%" >> "%ERROR_FILE%"
    )
)
DEL "%uploadErrFile%"

:: If requested, recursively upload files in all subfolders
IF %recurse%==true (
    SET /A newIndents=%numIndents%+2
    FOR /D %%D IN ("%dirPath%\*") DO (
        CALL :uploadFolder %%~fD\ !newIndents!
    )
)

EXIT /B 0
