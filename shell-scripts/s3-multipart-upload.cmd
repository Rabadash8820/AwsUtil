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
IF %errorCode%==1 EXIT /B 1
IF %errorCode%==2 EXIT /B 1

:: If help was requested then show proper usage and exit
IF %help%==true (
    CALL :showUsage
    EXIT /B 1
)

:: Otherwise, create the multipart-upload (just exit if there were errors)
CALL :createMultipartUpload
IF ERRORLEVEL 1 EXIT /B 1

:: Upload each part
SET ETAGS_FILE=upload-part-etags.json
CALL :uploadParts

:: Complete the multipart upload
CALL :completeMultipartUpload
DEL "%ETAGS_FILE%"

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void showUsage()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:showUsage

SETLOCAL EnableDelayedExpansion

SET archiver=WinRAR
>CON (
    ECHO Usage: s3-multipart-upload [options] <filedir>
    ECHO.
    ECHO    filedir          Path to the directory containing the object's parts.  The ONLY
    ECHO                     files that should be in this directory are the sequential parts
    ECHO                     of the object to be uploaded (generated, e.g., by HJ Split for
    ECHO                     Windows).
    ECHO.
    ECHO                     These files should fit the pattern "*.00?".  For example, you
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
    ECHO.
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
IF "%1"=="" (
    ECHO Error: Missing required arguments 1>&2
    ECHO.
    CALL :showUsage
    EXIT /B 1
)

:: Initialize arguments
SET help=false
SET options=""

:: Parse each argument
SET result=0

:loop
ECHO loop
IF "%1"=="" GOTO continueParse
SET validArg=false
    
:: Parse object file path
SET arg=%1
IF NOT "!arg:~0,1!"=="-" (
    IF DEFINED filedir (
        SET result=2
        ECHO Error: Only one file path may be provided for the object to upload! 1>&2
    ) ELSE (
        SET filedir=%1
        SHIFT
        SET validArg=true
    )
)

:: Parse bucket name
SET isBucket=false
IF "%1"=="-b" SET isBucket=true
IF "%1"=="/b" SET isBucket=true && IF "%1"=="/B" SET isBucket=true
IF "%1"=="--bucket" SET isBucket=true
IF !isBucket!==true (
    SET arg=%2
    IF "!arg!"=="" SET result=2
    IF "!arg:~0,1!"=="-" SET result=2
    IF !result!==0 (SHIFT) ELSE ECHO Error: --bucket requires an argument 1>&2
    SET bucket=!arg!
    SHIFT
)
IF !isBucket!==true SET validArg=true

:: Parse help flag
SET isHelp=false
IF "%1"=="-h" SET isHelp=true
IF "%1"=="/h" SET isHelp=true & IF "%1"=="/H" SET isHelp=true & IF "%1"=="/?" SET isHelp=true
IF "%1"=="--help" SET isHelp=true
IF !isHelp!==true (
    SET help=true
    SHIFT
)
IF !isHelp!==true SET validArg=true

:: Parse object key
SET isKey=false
IF "%1"=="-k" SET isKey=true
IF "%1"=="/k" SET isKey=true & IF "%1"=="/K" SET isKey=true
IF "%1"=="--key" SET isKey=true
IF !isKey!==true (
    SET arg=%2
    IF "!arg!"=="" SET result=2
    IF "!arg:~0,1!"=="-" SET result=2
    IF !result!==0 (SHIFT) ELSE ECHO Error: --key requires an argument 1>&2
    SET key=!arg!
    SHIFT
)
IF !isKey!==true SET validArg=true

:: Parse extra AWS options
SET isOptions=false
IF "%1"=="-o" SET isOptions=true
IF "%1"=="/o" SET isOptions=true & IF "%1"=="/O" SET isOptions=true
IF "%1"=="--options" SET isOptions=true
IF !isOptions!==true (
    SET arg=%2
    IF "!arg!"=="" SET result=2
    IF "!arg:~0,1!"=="-" SET result=2
    IF !result!==0 (SHIFT) ELSE ECHO Error: --options requires an argument 1>&2
    SET options=!arg!
    SHIFT
)
IF !isOptions!==true SET validArg=true

:: Parse AWS credentials profile
SET isProfile=false
IF "%1"=="-p" SET isProfile=true
IF "%1"=="/p" SET isProfile=true & IF "%1"=="/P" SET isProfile=true
IF "%1"=="--profile" SET isProfile=true
IF !isProfile!==true (
    SET arg=%2
    IF "!arg!"=="" SET result=2
    IF "!arg:~0,1!"=="-" SET result=2
    IF !result!==0 (SHIFT) ELSE ECHO Error: --profile requires an argument 1>&2
    SET profile=!arg!
    SHIFT
)
IF !isProfile!==true SET validArg=true

:: If this arg was invalid...
:: If a parsing error already occurred then skip over this block to keep the error messages precise
IF !result!==0 (
    IF !validArg!==false (
        ECHO Error: unrecognized argument "%1" 1>&2
        SET result=3
        SHIFT
    )
)

:: If there were any parsing errors then just exit
IF NOT !result!==0 EXIT /B !result!

ECHO    -b %bucket%
ECHO    -k %key%
ECHO    -p %profile%
ECHO    -o %options%
ECHO    filedir: %filedir%
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
ECHO Creating multipart upload for "%filedir%" to %key% in bucket %bucket%...
SET options=%options:"=%
IF NOT "%options%"=="" ECHO    Options: %options%
SET RESPONSE_FILE=response.txt
SET ERROR_FILE=error.txt
aws s3api create-multipart-upload --bucket "%bucket%" --key "%key%" %options% --profile "%profile%"> "%RESPONSE_FILE%" 2> "%ERROR_FILE%"

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
SET ID_FILE=upload-id.txt
FINDSTR /C:"UploadId" "%RESPONSE_FILE%"> "%ID_FILE%"
DEL "%RESPONSE_FILE%"
SET /P uploadID= < "%ID_FILE%"
DEL "%ID_FILE%"
SET uploadID=%uploadID:"=%          &:: Remove double quotes
SET uploadID=%uploadID: =%          &:: Remove spaces
SET uploadID=%uploadID:,=%          &:: Remove commas
SET uploadID=%uploadID:*:=%   &:: Remove leading text from AWS response
ECHO Creation succeeded with upload-id:
ECHO    %uploadID%

:: Unset local vars before exit
SET RESPONSE_FILE=
SET ERROR_FILE=
SET ID_FILE=
SET UPLOAD_STR=
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
ECHO Uploading object parts...
> "%ETAGS_FILE%" (
    ECHO {
    ECHO    "Parts": [
)

:: Add a JSON block for each object part
SET counter=0
SET TMP_FILE=tmp.txt
FOR %%F IN ("%filedir%\*.*.*") DO (
    :: Display progress
    SET /A counter+=1
    ECHO Uploading part !counter!/%numFiles%: %%F
    
    :: Get the ETag for this object part =%
    : Trim leading spaces and remove escpaed quotes =%
    echo uploadID: %uploadID%
    aws s3api upload-part --bucket "%bucket%" --key "%key%" --part-number !counter! --body %%F --upload-id %uploadID% --profile "%profile%" | findstr ETag> "%TMP_FILE%"
    SET /P etag= < "%TMP_FILE%"
    SET etag=!etag: =!
    SET etag=!etag::=: !
    SET etag=!etag:\"="!
    
    :: Export the JSON block for this part
     : Makes sure there's no comma after the last one!
    IF !counter!==%numFiles% (SET closeBrace=}) ELSE (SET closeBrace=},)
    >> %ETAGS_FILE% (
        ECHO        {
        ECHO            !etag!,
        ECHO            "PartNumber": !counter!
        ECHO        !closeBrace!
    )
)
DEL "%TMP_FILE%"

:: Add final lines to parts JSON file
>> %ETAGS_FILE% (
    ECHO    ]
    ECHO }
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: void completeMultipartUpload()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:completeMultipartUpload

EXIT /B 0
