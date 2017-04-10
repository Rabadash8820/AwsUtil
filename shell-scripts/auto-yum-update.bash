#!/bin/bash

stackName = $1
yumUpdateEmail = $2

# Install yum-cron to do automatic yum updates
# and postfix (a secure Mail Transfer Agent) and mailx to do email notifications
echo
echo Installing the yum-cron package...
yum install -y -q yum-cron    # -y and -q options must be separated for yum
echo Installing the postfix and mailx packages...
yum install -y -q postfix     # -y and -q options must be separated for yum
yum install -y -q mailx
echo Success!

# Configure hourly security updates and daily complete updates
cat > yum-cron-conf.sed <<- EOB
s|update_messages = no|update_messages = yes|
s|download_updates = no|download_updates = yes|
s|system_name = None|system_name = $stackName|
s|emit_via = stdio|emit_via = email|
s|email_from = root|email_from = yum-cron|
s|email_to = root|email_to = $yumUpdateEmail|
EOB
echo
echo Configuring hourly security updates...
sed -i "s|update_cmd = default|update_cmd = security|" /etc/yum/yum-cron-hourly.conf
sed -i -f yum-cron-conf.sed /etc/yum/yum-cron-hourly.conf
echo Configuring  daily complete updates...
sed -i -f yum-cron-conf.sed /etc/yum/yum-cron.conf
rm yum-cron-conf.sed
echo Success!

# Make sure yum-cron and postfix start after all future reboots
echo
echo Registering yum-cron to start on every reboot...
chkconfig yum-cron on
echo Registering postfix to start on every reboot...
chkconfig postfix on
echo Success!

# Clean yum and reboot to make sure everything's cool B)
echo
echo Rebooting...
yum clean all
reboot
echo Success!