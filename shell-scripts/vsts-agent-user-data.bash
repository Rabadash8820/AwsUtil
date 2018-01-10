#!/bin/bash

function configureAgent() {

    cd /home/ec2-user;

    # Download dotnet binaries and add them to PATH
    mkdir dotnet;
    cd dotnet;
    echo Downloading .NET Core...
    local dotnetTarball=dotnet.tar.gz
    curl --fail --location --output "$dotnetTarball" https://download.microsoft.com/download/5/F/0/5F0362BD-7D0A-4A9D-9BF9-022C6B15B04D/dotnet-runtime-2.0.0-linux-x64.tar.gz ;
    echo Download complete.
    echo Extracting .NET Core...
    tar --gzip --extract --file="$dotnetTarball";
    rm "$dotnetTarball";
    echo Extraction complete
    export PATH=$PATH:$(pwd);
    echo .NET Core added to PATH

    # Download the VSTS agent binaries
    printf "\n";
    mkdir ../vstsagent;
    cd ../vstsagent;
    echo Downloading the VSTS agent binaries...
    local agentTarball=vstsagent.tar.gz
    curl --fail --insecure --location --output "$agentTarball" https://vstsagentpackage.azureedge.net/agent/2.126.0/vsts-agent-linux-x64-2.126.0.tar.gz;
    echo Download complete
    echo Extracting VSTS agent binaries...
    tar --gzip --extract --file="$agentTarball";
    rm "$agentTarball";
    echo Extraction complete

    # Configure the agent
    printf "\n";
    echo Configuring VSTS agent...
    local agentType=build
    local vstsServerUrl="https:\\supplytech.visualstudio.com";
    local personalAccesstoken=fl3pnev7dx3gnt57zvflf3fhlc2laizondunn26rrephkgdmqlza;
    local agentPool=default;
    local agentName=aws-ec2-spot-agent;
    local teamProjectName=AdjustmentApp;
    local deploymentGroupName=AdjustmentApp-Development;
    local deploymentGroupTags="";
    if [ ${agentType} == build ]; then
        ./config.sh --unattended \
                    --url ${vstsServerUrl/\\/\\\\} \
                    --auth pat \
                    --token ${personalAccesstoken} \
                    --pool "${agentPool}" \
                    --agent "${agentName}";
    else
        ./config.sh --unattended \
                    --url ${vstsServerUrl/\\/\\\\} \
                    --auth pat \
                    --token ${personalAccesstoken} \
                    --pool "${agentPool}" \
                    --agent "${agentName}" \
                    --deploymentGroup \
                    --projectName "${teamProjectName}" \
                    --deploymentGroupName "${deploymentGroupName}" \
                    --addDeploymentGroupTags \
                    --deploymentGroupTags "${deploymentGroupTags}";
    fi
    echo VSTS agent configured

    # Start the agent as a service
    printf "\n";
    if [ -x "$(command -v systemctl)" ]; then
        echo Running VSTS agent as a service...
        ./svc.sh install;
        ./svc.sh start;
    else
        echo VSTS agent must be run interactively.
        echo Running VSTS agent now...
        ./run.sh;
    fi

    echo HEYYYY
    return $SUCCESS;
}

function addCapabilities() {
    # Update all YUM packages
    yum update --assumeyes;

    # Install Git
    yum install git --assumeyes;

    # Install Node.js/NPM
    curl --fail --location https://rpm.nodesource.com/setup_8.x | sudo bash - > /dev/null
    yum install --assumeyes nodejs

    return $SUCCESS;
}

function main() {

    declare -r SUCCESS=0;

    # Set up
    declare -r SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

    # Run the actual script logic
    addCapabilities;
    configureAgent;
    local -ri ERR_CODE=$?;

    # Tear down
    cd "$SCRIPT_DIR";
    return $ERR_CODE;
}

main;