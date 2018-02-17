# escape=`
FROM microsoft/aspnetcore-build:2.0-nanoserver-sac2016

# Set up the agent directory
WORKDIR C:\
COPY ./Start.* ./

# Configure the agent and run it as a Windows service
# Users can pass "--deploymentGroup" to the "docker run" command if they want to run the agent as a deployment group (release) agent.
CMD ["Start.cmd"]