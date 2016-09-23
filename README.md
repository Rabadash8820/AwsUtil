# AWSCloudInit
Bash scripts to be run by various AWS instance types during cloud-init.  

Make sure that none of these scripts contain Windows-style line endings ('\r' characters)!

## Usage
To use any of these cloud init scripts while configuring an AWS instance, paste the following code into its user data box.

`#!/bin/bash`  

`curl https://raw.githubusercontent.com/Rabadash8820/AWSCloudInit/master/SCRIPT_NAME_HERE.bash -o danware-cloud-init.bash`  
`chmod 700 danware-cloud-init.bash`  
`bash danware-cloud-init.bash`  
`rm danware-cloud-init.bash`  
