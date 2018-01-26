#!/bin/bash

function configureAgent() {

    cd /home/ubuntu;

    # Download the VSTS agent binaries
    printf "\n";
    mkdir vstsagent;
    cd vstsagent;
    local tarball=vssagent.tar.gz;
    echo Downloading the VSTS agent binaries...
    curl --silent --show-error --fail --insecure --location --output "$tarball" https://vstsagentpackage.azureedge.net/agent/2.126.0/vsts-agent-linux-x64-2.126.0.tar.gz;
    echo Download complete
    echo Extracting VSTS agent binaries...
    tar --gzip --extract --file "$tarball";
    rm "$tarball";
    echo Extraction complete

    # Install agent dependencies
    printf "\n";
    echo Installing dependencies \(as root\)...
    curl --silent --show-error --fail --location https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg;
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'   # for Ubuntu 16.4 (xenial)
    sudo apt-get update
    sudo apt-get install dotnet-sdk-2.1.3
    sudo ./bin/installdependencies.sh 2>&1 /dev/null;
    echo Dependencies installed

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
        echo Running VSTS agent as a service \(as root\)...
        sudo ./svc.sh install;
        sudo ./svc.sh start;
        echo Service started!
    else
        echo VSTS agent must be run interactively.
        echo Running VSTS agent now...
        ./run.sh;
    fi

    return $SUCCESS;
}

function addCapabilities() {
    # Update all YUM packages
    echo Upgrading all packages \(as root\)...
    sudo apt-get upgrade --quiet --assume-yes;
    echo Upgrade complete

    # Install Git
    printf "\n";
    echo Installing Git \(as root\)...
    sudo apt-get install --quiet --assume-yes git > /dev/null;
    echo Git installed

    # Install Node.js/NPM
    printf "\n";
    echo Installing Node.js/NPM \(as root\)...
    curl --silent --show-error --location https://deb.nodesource.com/setup_8.x | sudo --preserve-env bash -  2>&1 /dev/null;
    sudo apt-get install --quiet --assume-yes nodejs;
    echo Node.js/NPM installed

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