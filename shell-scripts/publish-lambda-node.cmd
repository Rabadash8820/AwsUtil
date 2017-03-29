:: Set up environment
@ECHO OFF

SETLOCAL EnableDelayedExpansion

:: Global paths
SET tempDir=%TEMP%\publish-lambda-node
SET PACKAGE_FILE=%tempDir%\package.zip
SET ERROR_FILE=%tempDir%\error.txt
SET RESPONSE_FILE=%tempDir%\response.txt

IF NOT EXIST "%tempDir%" MKDIR "%tempDir%"
TYPE NUL > "%ERROR_FILE%"
TYPE NUL > "%RESPONSE_FILE%"

:: Initialize global variables
SET function=""
SET help=false
SET options=""

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

:: Validate the provided path for the Lambda package
:: If there were any errors then display messages and exit
CALL :validatePackageDir & IF ERRORLEVEL 1 GOTO Catch

:: Create the Lambda package and upload it to S3
:: If a function name was provided then update its code with the new package
CALL :compressPackage & IF ERRORLEVEL 1 GOTO Catch
CALL :uploadPackage & IF ERRORLEVEL 1 GOTO Catch
CALL :updateFunctionCode & IF ERRORLEVEL 1 GOTO Catch

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
ECHO Usage: publish-lambda-node [options] ^<packageDir^> >> "%filename%"
IF %extended%==false (EXIT /B 0)

:: If the extended description was requested, then return this text
>> "%filename%" (
    ECHO.
    ECHO    packageDir       Required.  Path to the directory containing the Node.js files of
    ECHO                     the Lambda package you are uploading.  The files in this folder
    ECHO                     will be automatically compressed into a package using 7-Zip.
    ECHO.
    ECHO    --bucket         Required.  Name of the AWS S3 bucket to which you are uploading.
    ECHO                     By default, a key named "lambda-bucket-kms-key" will be used for
    ECHO                     server-side-encryption of the uploaded package.  You can change
    ECHO                     this behavior with the --options argument below.
    ECHO    -f, --function   Optional.  The name of a Lambda function to update with the new
    ECHO                     code.  This function must already be created.
    ECHO    -h, --help       Show this help text.
    ECHO    -k, --key        Required.  A unique key (name^) to identify the uploaded object
    ECHO                     in the bucket (e.g., "my-function.zip"^).
    ECHO    -p, --profile    Required.  A specific profile from your AWS CLI credential file.
    ECHO                     This profile must have already been created with "aws configure".
    ECHO                     Like with other AWS commands, you can also set the 
    ECHO                     AWS_DEFAULT_PROFILE environment variable beforehand.  Any actual
    ECHO                     value passed to --profile overrides this environment variable.
    ECHO    -o, --options    Options to pass to the put-object AWS CLI command.  Make sure 
    ECHO                     all options are enclosed in double quotes, e.g.:
    ECHO                     `--options "--metadata key=value --storage-class STANDARD_IA"`.
    ECHO                     Obviously, the following options have explicit arguments, so you
    ECHO                     should not pass them here:
    ECHO                        --body
    ECHO                        --bucket
    ECHO                        --key
    ECHO                        --profile
    ECHO                     And check with a supervisor before passing non-default values
    ECHO                     for these options:
    ECHO                        --acl
    ECHO                        --storage-class
    ECHO                        --server-side-encryption
    ECHO                        --ssekms-key-id
    ECHO.
    ECHO    Options can also be specified with a '/' character.  E.g., '/H' to show help.
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int parseArgs(string[] args)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:parseArgs

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

:: Parse part directory path
SET good=true
IF "%arg:~0,1%"=="-" (SET good=false)
IF "%arg:~0,1%"=="/" (SET good=false)
IF %good%==true (
    IF DEFINED packageDir (
        ECHO Error: You may provide the path to only one directory with package files to upload! >> "%ERROR_FILE%"
        EXIT /B 1
    ) ELSE (
        SET packageDir=%arg%
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

:: Parse Lambda function name
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isFunc=false
SET values=-f /f /F --function
FOR %%v IN (%values%) DO IF %arg%==%%v SET isFunc=true
IF %isFunc%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --function requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET function=!arg!
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

:: Parse object key
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isKey=false
SET values=-k /k /K --key
FOR %%v IN (%values%) DO IF %arg%==%%v SET isKey=true
IF %isKey%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --key requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET key=!arg!
    SHIFT
    GOTO loop
)

:: Parse extra AWS options
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isOptions=false
SET values=-o /o /O --options
FOR %%v IN (%values%) DO IF %arg%==%%v SET isOptions=true
IF %isOptions%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --options requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET options=!arg!
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

:: If this arg was invalid...
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
ECHO Error: unrecognized argument "%arg%" >> "%ERROR_FILE%"
EXIT /B 1

GOTO loop

:continueParse

:: If help was requested, then just early exit
IF %help%==true (EXIT /B 0)

:: Ensure required arguments were provided
SET valid=true
IF NOT DEFINED packageDir (SET valid=false & ECHO Error: You must provide a path to a directory containing package files >> "%ERROR_FILE%")
IF NOT DEFINED bucket (SET valid=false & ECHO Error: You must provide a bucket name (--bucket^) >> "%ERROR_FILE%")
IF NOT DEFINED key (SET valid=false & ECHO Error: You must provide an object key (--key^) >> "%ERROR_FILE%")

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

SET isBody=
SET isFunc=
SET isHelp=
SET isKey=
SET isOptions=
SET isProfile=

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int validatePackageDir(string packageDir)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:validatePackageDir

SETLOCAL EnableDelayedExpansion

:: Remove double quotes from the body path
SET packageDir=%packageDir:"=%

:: Make sure the provided path exists
IF NOT EXIST "%packageDir%" (
    ECHO Error: Could not find the path "%packageDir%" >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path is a directory, not a file
IF NOT EXIST "%packageDir%\*" (
    ECHO Error: The provided path must be a directory. >> "%ERROR_FILE%"
    ECHO "%packageDir%" is a file. >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the directory is not empty
SET numFiles=0
FOR %%f IN ("%packageDir%\*") DO SET /A numFiles+=1
IF %numFiles%==0 (
    ECHO No files were found in the provided directory. >> "%ERROR_FILE%"
    ECHO Lambda package creation cancelled. >> "%ERROR_FILE%"
    EXIT /B 1
)

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int compressPackage(string packageDir)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:compressPackage

SETLOCAL EnableDelayedExpansion

SET compressErrFile=%tempDir%\compressErr.txt

:: Remove any trailing slash from the provided directory path
SET hasSlash=false
IF %packageDir:~-1%==/ SET hasSlash=true
IF %packageDir:~-1%==\ SET hasSlash=true
IF %hasSlash%==true SET packageDir=%packageDir:~0,-1%

:: Compress the files in the provided directory using 7-Zip
ECHO.
ECHO Compressing the contents of the provided directory...
SET oldDir=%CD%
CD /D %packageDir%      &REM Without changing directories, 7-Zip would compress all files inside a parent folder, but Lambda expects files at the root
7z a -tzip -mx9 -mmt "%PACKAGE_FILE%" "*" > NUL 2> "%compressErrFile%"
CD /D %oldDir%

:: If any 7-Zip errors occurred then just log them and early exit
FOR /F %%i IN ("%compressErrFile%") DO SET size=%%~zi
IF /I %size% GTR 0 (
    ECHO Compression failed with error message: >> "%ERROR_FILE%"
    TYPE "%compressErrFile%" >> "%ERROR_FILE%"
    DEL "%compressErrFile%"
    EXIT /B 1
) ELSE (
    ECHO Lambda package created^^!
)
DEL "%compressErrFile%"

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int uploadPackage(string key, string profile, string options="")
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:uploadPackage

SETLOCAL EnableDelayedExpansion

SET uploadErrFile=%tempDir%\uploadErr.txt

:: Upload the package as an AWS S3 object (can't pass null string to --options argument)
SET options=%options:"=%
ECHO.
ECHO Uploading Lambda package to S3 with options:
ECHO    Key: %key%
IF NOT "%options%"=="" ECHO    Options: %options%
aws s3api put-object ^
    --bucket %bucket% ^
    --key %key% ^
    --body "%PACKAGE_FILE%" ^
    --acl private ^
    --storage-class STANDARD ^
    %options% ^
    --profile %profile% 2> "%uploadErrFile%" | findstr ETag> "%RESPONSE_FILE%"      &:: File redirection must occur on same line as last option
    REM --server-side-encryption aws:kms ^
    REM --ssekms-key-id alias/lambda-bucket-kms-key ^

:: If any AWS API errors occurred then just log them and early exit
FOR /F %%i IN ("%uploadErrFile%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Upload failed with error message: >> "%ERROR_FILE%"
    TYPE "%uploadErrFile%" >> "%ERROR_FILE%"
    DEL "%uploadErrFile%"
    EXIT /B 1
    
REM Otherwise, log the ETag for the newly uploaded object
) ELSE (
    SET /P etag= < "%RESPONSE_FILE%"
    SET etag=!etag: =!
    SET etag=!etag::=: !
    SET etag=!etag:\"=!
    SET etag=!etag:,=!
    ECHO Upload succeeded with !etag:"=!
)
DEL "%uploadErrFile%"

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int updateFunctionCode(string function, string key, string profile)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:updateFunctionCode

SETLOCAL EnableDelayedExpansion

SET updateErrFile=%tempDir%\updateErr.txt

:: If no function name was provided then just show a message and early exit
SET function=%function:"=%
IF "%function%"=="" (
    ECHO.
    ECHO No Lambda function selected for a code update.
    ECHO Complete^^!
    EXIT /B 0
)

:: Update the provided Lambda function's code
ECHO.
ECHO Updating Lambda function "%function%"...
aws lambda update-function-code ^
    --function-name %function% ^
    --s3-bucket %bucket% ^
    --s3-key %key% ^
    --no-publish ^
    --profile %profile% > "%RESPONSE_FILE%" 2> "%updateErrFile%"      &:: File redirection must occur on same line as last option

:: If any AWS API errors occurred then just log them and early exit
FOR /F %%i IN ("%updateErrFile%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Code update failed with error message: >> "%ERROR_FILE%"
    TYPE "%updateErrFile%" >> "%ERROR_FILE%"
    DEL "%updateErrFile%"
    EXIT /B 1
) ELSE (
    ECHO Code update succeeded^^!
)
DEL "%updateErrFile%"

EXIT /B 0
