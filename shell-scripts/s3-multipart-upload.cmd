::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int main(string[] args)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main

:: Set up environment
@ECHO OFF
SETLOCAL EnableDelayedExpansion

:: Parse arguments
CALL :parseArgs %*

:: If there were any parsing errors then just exit
SET errorCode=%ERRORLEVEL%
IF NOT %errorCode%==0 EXIT /B 1

:: If help was requested then show proper usage and exit
IF %help%==true (
    CALL :showUsage
    EXIT /B 1
)

:: Otherwise, create the multipart-upload (just exit if there were errors)
CALL :createMultipartUpload
IF ERRORLEVEL 1 EXIT /B 1

:: Upload each part
SET ETAGS_JSON=%CD%\upload-part-etags.json
CALL :uploadParts

:: Complete the multipart upload
CALL :completeMultipartUpload
REM DEL "%ETAGS_JSON%"

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void showUsage()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:showUsage

SETLOCAL EnableDelayedExpansion

>CON (
    ECHO.
    ECHO Usage: s3-multipart-upload [options] ^<filedir^>
    ECHO.
    ECHO    filedir          Path to the directory containing the object's parts.  The ONLY
    ECHO                     files that should be in this directory are the sequential parts
    ECHO                     of the object to be uploaded (generated, e.g., by HJ Split for
    ECHO                     Windows^).
    ECHO.
    ECHO                     These files should fit the pattern "*.*.*".  For example, you
    ECHO                     might have a file called "mydata.zip" that was split into
    ECHO                     10 parts with HJ Split, generating the files mydata.zip.001,
    ECHO                     mydata.zip.002, etc., in a directory such as "C:\data\mydata\".
    ECHO.
    ECHO    -b, --bucket     Required.  Name of the AWS S3 bucket to which you are uploading.
    ECHO    -h, --help       Show this help text.
    ECHO    -k, --key        Required.  A unique key (name^) to identify the uploaded object
    ECHO                     in the bucket (e.g., "my-file"^).
    ECHO    -p, --profile    Required.  A specific profile from your AWS CLI credential file.
    ECHO                     This profile must have already been created with "aws configure".
    ECHO                     Like with other AWS commands, you can also set the 
    ECHO                     AWS_DEFAULT_PROFILE environment variable beforehand.  Any actual
    ECHO                     value passed to --profile overrides this environment variable.
    ECHO    -o, --options    Options to pass to the create-multipart-upload command.  Make
    ECHO                     sure all options are enclosed in double quotes, e.g.:
    ECHO                     `--options "--metadata key=value --storage-class STANDARD_IA"`
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int parseArgs(string[] args)
::
:: Error levels:
::    0 - parsed without error
::    1 - no arguments provided
::    2 - argument was missing subsequent arguments
::    3 - unrecognized argument
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:parseArgs

:: If no arguments were provided then show usage and exit
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
IF "%arg%"=="" (
    ECHO Error: Missing required arguments 1>&2
    ECHO.
    CALL :showUsage
    EXIT /B 1
)

:: Initialize arguments
SET help=false
SET options=""

:loop
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO (SET arg=%%~a)   &:: Remove double quotes
IF "%arg%"=="" GOTO continueParse

:: Parse part directory path
IF NOT "%arg:~0,1%"=="-" (
    IF DEFINED filedir (
        ECHO Error: Only one file path may be provided for the object to upload! 1>&2
        EXIT /B 2
    ) ELSE (
        SET filedir=%arg%
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
    IF "!arg:~0,1!"=="-" SET good=false
    IF !good!==true (SHIFT) ELSE (ECHO Error: --bucket requires an argument 1>&2 & EXIT /B 2)
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
    IF "!arg:~0,1!"=="-" SET good=false
    IF !good!==true (SHIFT) ELSE (ECHO Error: --key requires an argument 1>&2 & EXIT /B 2)
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
    IF "!arg:~0,1!"=="-" SET good=false
    IF !good!==true (SHIFT) ELSE (ECHO Error: --options requires an argument 1>&2 & EXIT /B 2)
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
    IF "!arg:~0,1!"=="-" SET good=false
    IF !good!==true (SHIFT) ELSE (ECHO Error: --profile requires an argument 1>&2 & EXIT /B 2)
    SET profile=!arg!
    SHIFT
    GOTO loop
)

:: If this arg was invalid...
SET arg=%1
FOR /F "usebackq tokens=*" %%a IN ('%arg%') DO SET arg=%%~a
ECHO Error: unrecognized argument "%arg%" 1>&2
EXIT /B 3

GOTO loop

:continueParse

:: If help was requested, then just show usage and exit
IF %help%==true (EXIT /B 0)

:: Validate arguments
SET valid=true
IF NOT DEFINED bucket (SET valid=false & ECHO Error: You must provide a bucket name (--bucket^)! 1>&2)
IF NOT DEFINED filedir (SET valid=false & ECHO Error: You must provide a path to a directory containing object parts! 1>&2)
IF NOT DEFINED key (SET valid=false & ECHO Error: You must provide an object key (--key^)! 1>&2)
IF NOT DEFINED profile (
    IF DEFINED AWS_DEFAULT_PROFILE (
        SET profile=%AWS_DEFAULT_PROFILE%
    ) ELSE (
        SET valid=false
        ECHO Error: You must provide an AWS CLI credentials profile (--profile^)! 1>&2
    )
)
IF %valid%==false EXIT /B 1

:: Unset local vars before exit
SET arg=
SET validArg=
SET valid=
SET result=

SET isBucket=
SET isFile=
SET isHelp=
SET isKey=
SET isOptions=
SET isProfile=

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void createMultipartUpload(string bucket, string key, string metadata="", string profile, ref uploadID)
::
:: If successful, the upload-id of the new multipart upload is stored in uploadID
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:createMultipartUpload

:: Create the AWS S3 multipart upload (can't pass null string to --metadata argument)
SET filedir=%filedir:"=%
SET options=%options:"=%
ECHO.
ECHO Creating multipart upload with options:
ECHO    Bucket: %bucket%
ECHO    Key: %key%
IF NOT "%options%"=="" ECHO    Options: %options%
SET RESPONSE_FILE=response.txt
SET ERROR_FILE=error.txt
aws s3api create-multipart-upload --bucket %bucket% --key %key% %options% --profile %profile%> "%RESPONSE_FILE%" 2> "%ERROR_FILE%"

:: Rethrow any error messages from the AWS API
FOR /F %%i IN ("%ERROR_FILE%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Creation failed with error message: 1>&2
    TYPE "%ERROR_FILE%" 1>&2
    DEL "%ERROR_FILE%"
    EXIT /B 1
)
DEL "%ERROR_FILE%"

:: Store the new upload ID
:: Remove double quotes, spaces, commas, and leading text from AWS response
SET ID_FILE=upload-id.txt
FINDSTR /C:"UploadId" "%RESPONSE_FILE%"> "%ID_FILE%"
DEL "%RESPONSE_FILE%"
SET /P uploadID= < "%ID_FILE%"
DEL "%ID_FILE%"
SET uploadID=%uploadID:"=%
SET uploadID=%uploadID: =%
SET uploadID=%uploadID:,=%
SET uploadID=%uploadID:*:=%
ECHO Creation succeeded with upload-id:
ECHO    %uploadID%

:: Unset local vars before exit
SET RESPONSE_FILE=
SET ERROR_FILE=
SET ID_FILE=
SET size=

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void uploadParts(string filedir)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:uploadParts

SETLOCAL EnableDelayedExpansion

:: Count the number of file parts in the provided directory
SET numFiles=0
FOR %%F IN ("%filedir%\*.*.*") DO SET /A numFiles+=1

:: Add initial lines to parts JSON file
ECHO.
ECHO Uploading object parts from directory "%filedir%"...
> "%ETAGS_JSON%" (
    ECHO {
    ECHO    "Parts": [
)

:: Add a JSON block for each object part
SET counter=0
SET TMP_FILE=tmp.txt
FOR %%F IN ("%filedir%\*.*.*") DO (
    :: Display progress
    SET /A counter+=1
    ECHO     Uploading part !counter!/%numFiles%: %%~nF
    
    :: Store the ETag for this object part
     : Remove spaces, colons, and escaped double quotes
    aws s3api upload-part --bucket %bucket% --key %key% --part-number !counter! --body "%%F" --upload-id %uploadID% --profile %profile% | findstr ETag> "%TMP_FILE%"
    SET /P etag= < "%TMP_FILE%"
    SET etag=!etag: =!
    SET etag=!etag::=: !
    SET etag=!etag:\"=!
    ECHO         !etag:"=!
    
    :: Export the JSON block for this part
     : Makes sure there's no comma after the last one!
    IF !counter!==%numFiles% (SET closeBrace=}) ELSE (SET closeBrace=},)
    >> "%ETAGS_JSON%" (
        ECHO        {
        ECHO            !etag!,
        ECHO            "PartNumber": !counter!
        ECHO        !closeBrace!
    )
)
DEL "%TMP_FILE%"

:: Add final lines to parts JSON file
>> "%ETAGS_JSON%" (
    ECHO    ]
    ECHO }
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void completeMultipartUpload()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:completeMultipartUpload

SETLOCAL EnableDelayedExpansion

:: Create the AWS S3 multipart upload (can't pass null string to --metadata argument)
SET filedir=%filedir:"=%
ECHO.
ECHO Completing the multipart upload to %key% in bucket %bucket%...
SET RESPONSE_FILE=response.txt
SET ERROR_FILE=error.txt
aws s3api complete-multipart-upload --bucket %bucket% --key %key% --profile %profile% --multipart-upload file://"%ETAGS_JSON%" --upload-id %uploadID%> "%RESPONSE_FILE%" 2> "%ERROR_FILE%"
DEL "%ETAGS_JSON%"

:: Rethrow any error messages from the AWS API
FOR /F %%i IN ("%ERROR_FILE%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Completion failed with error message: 1>&2
    TYPE "%ERROR_FILE%" 1>&2
    DEL "%ERROR_FILE%"
    EXIT /B 1
)
DEL "%ERROR_FILE%"

:: Store the new upload ID
:: Remove double quotes, spaces, commas, and leading text from AWS response
SET LOC_FILE=s3loc.txt
FINDSTR /C:"Location" "%RESPONSE_FILE%"> "%LOC_FILE%"
DEL "%RESPONSE_FILE%"
SET /P s3loc= < "%LOC_FILE%"
DEL "%LOC_FILE%"
SET s3loc=%s3loc:"=%
SET s3loc=%s3loc: =%
SET s3loc=%s3loc:,=%
SET s3loc=%s3loc:*:=%
ECHO Completion succeeded with S3 location:
ECHO     %s3loc%

EXIT /B 0
