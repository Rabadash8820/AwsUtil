:: Set up environment
@ECHO OFF

SETLOCAL EnableDelayedExpansion

:: Global paths
SET tempDir=%TEMP%\publish-lambda-node
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
CALL :validatePackage & IF ERRORLEVEL 1 GOTO Catch

:: If everything looks good, then upload the Lambda package to S3
CALL :uploadPackage & IF ERRORLEVEL 1 GOTO Catch

:: If the name of a Lambda function was provided then also update that function's code
SET function=%function:"=%
IF NOT "%function%"=="" (
    CALL :updateFunctionCode & IF ERRORLEVEL 1 GOTO Catch
)

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
ECHO Usage: publish-lambda-node [options] >> "%filename%"
IF %extended%==false (EXIT /B 0)

:: If the extended description was requested, then return this text
>> "%filename%" (
    ECHO.
    ECHO    --body           Required.  Path to the Node.js Lambda package you are uploading.
    ECHO                     The package body must be a .zip file.
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

:: Parse body path
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isBody=false
SET values=--body
FOR %%v IN (%values%) DO IF %arg%==%%v SET isBody=true
IF %isBody%==true (
    SET arg=%2
    SET good=true
    IF "!arg!"=="" SET good=false
    IF "!arg:~0,1!"=="-" (SET good=false)
    IF "!arg:~0,1!"=="/" (SET good=false)
    IF !good!==true (SHIFT) ELSE (ECHO Error: --body requires an argument >> "%ERROR_FILE%" & EXIT /B 1)
    SET bodyPath=!arg!
    SHIFT
    GOTO loop
)

:: Parse bucket name
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" GOTO continueParse
SET isBucket=false
SET values=--bucket
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
IF NOT DEFINED bodyPath (SET valid=false & ECHO Error: You must provide a path to the object's body (--body^)! >> "%ERROR_FILE%")
IF NOT DEFINED bucket (SET valid=false & ECHO Error: You must provide a bucket name (--bucket^)! >> "%ERROR_FILE%")
IF NOT DEFINED key (SET valid=false & ECHO Error: You must provide an object key (--key^)! >> "%ERROR_FILE%")

:: Try to set the missing AWS credentials profile with an environment variable
IF NOT DEFINED profile (
    IF DEFINED AWS_DEFAULT_PROFILE (
        SET profile=%AWS_DEFAULT_PROFILE%
    ) ELSE (
        SET valid=false
        ECHO Error: You must provide an AWS CLI credentials profile (--profile^)! >> "%ERROR_FILE%"
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
:: int validatePackage(string bodyPath)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:validatePackage

SETLOCAL EnableDelayedExpansion

:: Remove double quotes from the body path
SET bodyPath=%bodyPath:"=%

:: Make sure the provided path exists
IF NOT EXIST "%bodyPath%" (
    ECHO Error: Could not find the package "%bodyPath%" >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path is a file, not a directory
IF EXIST "%bodyPath%\*" (
    ECHO Error: The provided package must be a .zip file. >> "%ERROR_FILE%"
    ECHO "%bodyPath%" is a directory. >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path is a zip file
SET ext=""
FOR %%f IN ("%bodyPath%") DO SET ext=%%~xf
IF NOT %ext%==.zip (
    ECHO Error: The provided package must be a .zip file. >> "%ERROR_FILE%"
    ECHO "%bodyPath%" is a %ext% file. >> "%ERROR_FILE%"
    EXIT /B 1
)

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int uploadPackage(string key, string bodypath, string profile, string options="")
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
    --body "%bodyPath%" ^
    --acl private ^
    --storage-class STANDARD ^
    --server-side-encryption aws:kms ^
    --ssekms-key-id alias/lambda-bucket-kms-key ^
    %options% ^
    --profile %profile% 2> "%uploadErrFile%" | findstr ETag> "%RESPONSE_FILE%"      &:: File redirection must occur on same line as last option

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

SET updateErrFile=%tempDir%\uploadErr.txt

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
