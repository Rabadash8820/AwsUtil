#!/bin/bash

publicDns = $1

echo
echo Adjusting HOSTNAME to match the provided public DNS name
sed -i "s|HOSTNAME=localhost.localdomain|HOSTNAME=$publicDns|" /etc/sysconfig/network
echo Success!