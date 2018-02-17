$ErrorActionPreference = "Stop"

# Validate VSTS account
If ($env:VSTS_AGENT_INPUT_ACCOUNT -eq $null) {
    Write-Error "Missing VSTS_AGENT_INPUT_ACCOUNT environment variable"
    exit 1
}

# Validate VSTS personal access token
if ($env:VSTS_AGENT_INPUT_TOKEN -eq $null) {
    Write-Error "Missing VSTS_AGENT_INPUT_TOKEN environment variable"
    exit 1
} else {
    if (Test-Path -Path $env:VSTS_AGENT_INPUT_TOKEN -PathType Leaf) {
        $env:VSTS_AGENT_INPUT_TOKEN = Get-Content -Path $env:VSTS_AGENT_INPUT_TOKEN -ErrorAction Stop | Where-Object {$_} | Select-Object -First 1
        
        if ([string]::IsNullOrEmpty($env:VSTS_AGENT_INPUT_TOKEN)) {
            Write-Error "Missing VSTS_AGENT_INPUT_TOKEN file content"
            exit 1
        }
    }
}

# Set agent name if not already set in the environment
if ($env:VSTS_AGENT_INPUT_AGENT -ne $null) {
    $env:VSTS_AGENT_INPUT_AGENT = $($env:VSTS_AGENT_INPUT_AGENT)
}
else {
    $env:VSTS_AGENT_INPUT_AGENT = $env:COMPUTERNAME
}

# Set agent work directory if not already set in the environment
if ($env:VSTS_AGENT_INPUT_WORK -ne $null) {
    New-Item -Path $env:VSTS_AGENT_INPUT_WORK -ItemType Directory -Force
}
else {
    $env:VSTS_AGENT_INPUT_WORK = "_work"
}

# Set agent pool if not already set
if($env:VSTS_AGENT_INPUT_POOL -eq $null) {
    $env:VSTS_AGENT_INPUT_POOL = "Default"
}

# Get the download URI for the latest build agent software
$useragent = 'vsts-windowscontainer'
$creds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($("user:$env:VSTS_AGENT_INPUT_TOKEN")))
$encodedAuthValue = "Basic $creds"
$acceptHeaderValue = "application/json;api-version=3.0-preview"
$headers = @{Authorization = $encodedAuthValue;Accept = $acceptHeaderValue }
$vstsUrl = "https://$env:VSTS_AGENT_INPUT_ACCOUNT.visualstudio.com/_apis/distributedtask/packages/agent?platform=win7-x64&`$top=1"
$response = Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $vstsUrl -UserAgent $useragent
$response = ConvertFrom-Json $response.Content

# Download and extract the agent software
Write-Host "Download agent to C:\vstsagent.zip"
Invoke-WebRequest -Uri $response.value[0].downloadUrl -OutFile C:\vstsagent.zip
Write-Host "Extract vstsagent.zip"
Expand-Archive -Path C:\vstsagent.zip -DestinationPath C:\vstsagent
Write-Host "Deleting vstsagent.zip"
Remove-Item -Path C:\vstsagent.zip

# No idea what this does... taken from the original Start.ps1 at https://github.com/Microsoft/vsts-agent-docker/blob/master/windows/servercore/10.0.14393/Start.ps1
$env:VSO_AGENT_IGNORE="VSTS_AGENT_URL,VSO_AGENT_IGNORE,VSTS_AGENT_INPUT_AGENT,VSTS_AGENT_INPUT_ACCOUNT,VSTS_AGENT_INPUT_TOKEN,VSTS_AGENT_INPUT_POOL,VSTS_AGENT_INPUT_WORK"
if ($env:VSTS_AGENT_IGNORE -ne $null) {
    $env:VSO_AGENT_IGNORE="$env:VSO_AGENT_IGNORE,$env:VSTS_AGENT_IGNORE,VSTS_AGENT_IGNORE"
}

# Configure and run the agent!
Write-Host "Configuring the agent"
Set-Location -Path "C:\vstsagent"
& .\bin\Agent.Listener.exe configure --unattended --replace --auth PAT
Write-Host "Running the agent"
& .\bin\Agent.Listener.exe run
