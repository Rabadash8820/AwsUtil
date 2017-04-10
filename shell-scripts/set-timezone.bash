#!/bin/bash

timeZone = $1

echo
echo Adjusting time zone to $timeZone...
sed -ir "s|ZONE=\"UTC\"|ZONE=\"$timeZone\"|" /etc/sysconfig/clock
ln -sf /usr/share/zoneinfo/$timeZone /etc/localtime
echo Success!