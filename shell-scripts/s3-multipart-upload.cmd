:: Set up environment
@ECHO OFF

SETLOCAL EnableDelayedExpansion

:: Global files
SET ERROR_FILE=error.txt
SET RESPONSE_FILE=response.txt
SET UPLOAD_ID_FILE=upload-id.txt
SET ETAGS_JSON=%CD%\upload-part-etags.json

TYPE NUL > "%ERROR_FILE%"
TYPE NUL > "%RESPONSE_FILE%"
TYPE NUL > "%UPLOAD_ID_FILE%"
TYPE NUL > "%ETAGS_JSON%"

:: Initialize global variables
SET help=false
SET options=""
SET uploadID=""

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int main(string[] args)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:main

SET errCode=0

:: Parse arguments
:: If there were any errors then display messages and exit
CALL :parseArgs %* & IF ERRORLEVEL 1 GOTO Catch

:: If help was requested then show proper usage and exit
IF %help%==true (
    ECHO. > CON
    CALL :showUsage CON true
    GOTO Finally
)

:: Validate the provided directory
:: If there were any errors then display messages and exit
CALL :validatePath & IF ERRORLEVEL 1 GOTO Catch

:: If everything looks good, then:
:: create the multipart-upload, upload each part, and complete the multipart-upload
:: If there were any errors then display messages and exit
CALL :createMultipartUpload "%UPLOAD_ID_FILE%" & IF ERRORLEVEL 1 GOTO Catch
SET /P uploadID= < "%UPLOAD_ID_FILE%"
CALL :uploadParts & IF ERRORLEVEL 1 GOTO Catch
CALL :completeMultipartUpload & IF ERRORLEVEL 1 GOTO Catch

:Catch
TYPE "%ERROR_FILE%" 1>&2
SET errCode=1
GOTO Finally

:Finally
DEL "%ERROR_FILE%"
DEL "%RESPONSE_FILE%"
DEL "%UPLOAD_ID_FILE%"
DEL "%ETAGS_JSON%"
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
ECHO Usage: s3-multipart-upload [options] ^<filedir^> >> "%filename%"
IF %extended%==false (EXIT /B 0)

:: If the extended description was requested, then return this text
>> "%filename%" (
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
IF NOT "%arg:~0,1%"=="-" (
    IF DEFINED filedir (
        ECHO Error: You may provide the path to only one directory with object parts to upload! >> "%ERROR_FILE%"
        EXIT /B 1
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
    IF "!arg:~0,1!"=="-" SET good=false
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
    IF "!arg:~0,1!"=="-" SET good=false
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

:: If help was requested, then just exit
IF %help%==true (EXIT /B 0)

:: Ensure required arguments were provided
SET valid=true
IF NOT DEFINED bucket (SET valid=false & ECHO Error: You must provide a bucket name (--bucket^)! >> "%ERROR_FILE%")
IF NOT DEFINED filedir (SET valid=false & ECHO Error: You must provide a path to a directory containing object parts! >> "%ERROR_FILE%")
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

SET isBucket=
SET isFile=
SET isHelp=
SET isKey=
SET isOptions=
SET isProfile=

EXIT /B 0


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int validatePath(string filedir)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:validatePath

SETLOCAL EnableDelayedExpansion

:: Make sure the provided path exists
IF NOT EXIST %filedir% (
    ECHO Error: Could not find the path "%filedir%" >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Make sure the provided path is a directory, not a file
IF NOT EXIST "%filedir%\*" (
    ECHO Error: The provided path must be a directory. >> "%ERROR_FILE%"
    ECHO "%filedir%" is a file. >> "%ERROR_FILE%"
    EXIT /B 1
)

:: Get the number of files and object parts in the provided directory
SET numFiles=0
FOR %%f IN ("%filedir%\*") DO SET /A numFiles+=1

SET numParts=0
FOR %%F IN ("%filedir%\*") DO (
    SET ext=%%~xF
    SET ext=!ext:.=!
    SET nonNumeric=
    FOR /f "delims=0123456789" %%i IN ("!ext!") DO SET nonNumeric=%%i
    IF NOT DEFINED nonNumeric SET /A numParts+=1
)

:: Make sure that at least one object part was provided,
:: and that object parts are the ONLY files in the directory
IF %numFiles%==0 (
    ECHO No file parts were found in the provided directory. >> "%ERROR_FILE%"
    ECHO Parts are expected to be in the format "filename.ext.123" >> "%ERROR_FILE%"
    EXIT /B 1
)
IF NOT %numParts%==%numFiles% (
    >> "%ERROR_FILE%" (
        ECHO Error: Object parts must be the only files in this directory.
        ECHO    Object parts found in the provided directory: %numParts%
        ECHO    Total files found: %numFiles%
        ECHO Parts are expected to be in the format "filename.ext.123"
    )
    EXIT /B 1
)

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int createMultipartUpload(string uploadIdFile, string bucket, string key, string options="", string profile)
::
:: If successful, the upload-id of the new multipart upload will be stored to the provided file
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:createMultipartUpload

SETLOCAL EnableDelayedExpansion

SET uploadIdFile=%1
SET createErrFile=createErr.txt

:: Create the AWS S3 multipart upload (can't pass null string to --metadata argument)
SET filedir=%filedir:"=%
SET options=%options:"=%
ECHO.
ECHO Creating multipart upload with options:
ECHO    Bucket: %bucket%
ECHO    Key: %key%
IF NOT "%options%"=="" ECHO    Options: %options%
aws s3api create-multipart-upload --bucket %bucket% --key %key% %options% --profile %profile% > "%RESPONSE_FILE%" 2> "%createErrFile%"

:: Rethrow any error messages from the AWS API
FOR /F %%i IN ("%createErrFile%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Creation failed with error message: >> "%ERROR_FILE%"
    TYPE "%createErrFile%" >> "%ERROR_FILE%"
    DEL "%createErrFile%"
    EXIT /B 1
)
DEL "%createErrFile%"

:: Store the new upload ID
:: Remove double quotes, spaces, commas, and leading text from AWS response
FINDSTR /C:"UploadId" "%RESPONSE_FILE%"> "%uploadIdFile%"
SET /P uploadID= < "%uploadIdFile%"
SET uploadID=%uploadID:"=%
SET uploadID=%uploadID: =%
SET uploadID=%uploadID:,=%
SET uploadID=%uploadID:*:=%
ECHO %uploadID%> "%uploadIdFile%"
ECHO Creation succeeded with upload-id:
ECHO    %uploadID%

EXIT /B 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int uploadParts(string filedir)
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:uploadParts

SETLOCAL EnableDelayedExpansion

SET uploadErrFile=uploadErr.txt

:: Count the number of file parts in the provided directory
SET numFiles=0
FOR %%F IN ("%filedir%\*") DO SET /A numFiles+=1

:: Add initial lines to parts JSON file
ECHO.
ECHO Uploading object parts from directory "%filedir%"...
> "%ETAGS_JSON%" (
    ECHO {
    ECHO    "Parts": [
)

:: Add a JSON block for each object part
SET counter=0
SET numErrs=0
FOR %%F IN ("%filedir%\*") DO (
    :: Display progress
    SET /A counter+=1
    ECHO     Uploading part !counter!/%numFiles%: %%~nF%%~xF  ^(%%~zF bytes^)
    
    :: Attempt to upload this object part
    aws s3api upload-part --bucket %bucket% --key %key% --part-number !counter! --body "%%F" --upload-id %uploadID% --profile %profile% 2> "%uploadErrFile%" | findstr ETag> "%RESPONSE_FILE%"

    :: If any AWS API errors occurred then log them and continue to the next object part
    SET size=0
    FOR /F %%s IN ("%uploadErrFile%") DO SET size=%%~zs
    IF /I !size! GTR 0 (
        ECHO         Failed^^!  More details will be provided at the end. > CON
        IF !numErrs!==0 (
            SET /A numErrs+=1
            >> "%ERROR_FILE%" (
                ECHO.
                ECHO This multipart upload could not be completed because at least one part failed to upload.
                ECHO Using the AWS CLI, you must either abort, or manually re-upload the failed parts and complete.
                ECHO Here are some more details:
                ECHO.
            )
        )
        ECHO     Upload of part !counter!/%numFiles% failed with error message: >> "%ERROR_FILE%"
        TYPE "%uploadErrFile%" >> "%ERROR_FILE%"
        
    REM Otherwise, store the ETag for this object part and log its JSON block
    ) ELSE (
        SET /P etag= < "%RESPONSE_FILE%"
        SET etag=!etag: =!
        SET etag=!etag::=: !
        SET etag=!etag:\"=!
        ECHO         Succeeded with !etag:"=!
        
        IF !counter!==%numFiles% (SET closeBrace=}) ELSE (SET closeBrace=},)    &REM Make sure there's no comma after the last block!
        >> "%ETAGS_JSON%" (
            ECHO        {
            ECHO            !etag!,
            ECHO            "PartNumber": !counter!
            ECHO        !closeBrace!
        )
    )
)
DEL "%uploadErrFile%"

:: Add final lines to parts JSON file
>> "%ETAGS_JSON%" (
    ECHO    ]
    ECHO }
)


EXIT /B %numErrs%

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: int completeMultipartUpload()
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:completeMultipartUpload

SETLOCAL EnableDelayedExpansion

SET completeErrFile=completeErr.txt

:: Create the AWS S3 multipart upload (can't pass null string to --metadata argument)
SET filedir=%filedir:"=%
ECHO.
ECHO Completing the multipart upload to %key% in bucket %bucket%...
aws s3api complete-multipart-upload --bucket %bucket% --key %key% --profile %profile% --multipart-upload file://"%ETAGS_JSON%" --upload-id %uploadID%> "%RESPONSE_FILE%" 2> "%completeErrFile%"

:: Rethrow any error messages from the AWS API
FOR /F %%i IN ("%completeErrFile%") DO SET size=%%~zi
IF %size% GTR 0 (
    ECHO Completion failed with error message: >> "%ERROR_FILE%"
    TYPE "%completeErrFile%" >> "%ERROR_FILE%"
    DEL "%completeErrFile%"
    EXIT /B 1
)
DEL "%completeErrFile%"

:: Store the new upload ID
:: Remove double quotes, spaces, commas, and leading text from AWS response
SET LOC_FILE=s3loc.txt
FINDSTR /C:"Location" "%RESPONSE_FILE%"> "%LOC_FILE%"
SET /P s3loc= < "%LOC_FILE%"
DEL "%LOC_FILE%"
SET s3loc=%s3loc:"=%
SET s3loc=%s3loc: =%
SET s3loc=%s3loc:,=%
SET s3loc=%s3loc:*:=%
ECHO Completion succeeded!  Your object is now stored in S3 at:
ECHO     %s3loc%

EXIT /B 0
