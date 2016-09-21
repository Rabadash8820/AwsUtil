#!/bin/bash

# Define constants
SERVERNAME=danware                  # should not contain spaces    
P4SERVERDIR=/opt/perforce/servers	# should not contain spaces
P4ROOTDIR=$P4SERVERDIR/$serverName    # should not contain spaces
FILESDIR=$P4ROOTDIR/files             # should not contain spaces
SSLDIR=$P4ROOTDIR/ssl                 # should not contain spaces
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ:0:-1}
SERVERDNS=p4.danvicarel.com

# Add a newline to the ec2-user prompt string
echo PS1="\"\\n\$PS1\"">> /home/ec2-user/.bashrc

# Update all packages
yum update -y

# Install Perforce packages
# The RHEL/7 part of the baseurl should be replaced with
# the latest RHEL version that both Amazon and Perforce support
rpm -import https://package.perforce.com/perforce.pubkey
tee /etc/yum.repos.d/perforce.repo <<- EOB
[perforce]
name=Perforce
baseurl=http://package.perforce.com/yum/rhel/7/x86_64
enabled=1
gpgcheck=1
EOB
yum install -y helix-p4d

# ***** UNCOMMENT IF NECESSARY *****
# # Format EBS volumes
# dev1=/dev/sdb     # should not contain spaces
# dbLbl=p4db        # should not contain spaces
# chkptLbl=p4chkpt
# parted -s $dev1 mktable gpt
# parted -s -a optimal $dev1 mkpart primary xfs 0% 100%
# parted -s $dev1 name 1 $dbLbl
# yum install -y xfsprogs
# mkfs -t xfs "$dev1"1
# xfs_admin -L $dbLbl "$dev1"1

# Make directories for the server, owned by new "perforce" user
mkdir -p $FILESDIR $SSLDIR
chown -R perforce:perforce $P4ROOTDIR
chmod 700 $SSLDIR

# Set up automatic mounts (for this and all future reboots)
yum install -y curl
efsID=fs-1768925e
echo "${AZ}.${efsID}.efs.${REGION}.amazonaws.com:/ $FILESDIR nfs4 defaults,vers=4.1,noresvport 0 0" >> /etc/fstab
yum install -y nfs-utils    # should already be installed in Amazon Linux AMIs
mount -a -t nfs4

# Configure the Perforce server daemon
journalPath=$P4ROOTDIR/journal.live   # should not contain spaces
tee /etc/perforce/p4dctl.conf.d/$SERVERNAME.conf <<- EOB
p4d danware
{
    Owner       = perforce
    Execute     = /opt/perforce/sbin/p4d
    Umask       = 077
    PrettyNames = true
    Prefix      = $SERVERNAME
    Enabled     = true
    
    Environment {
        P4ROOT    = $FILESDIR
        P4JOURNAL = $journalPath
        P4PORT    = ssl:1666
        P4SSLDIR  = $SSLDIR
        PATH      = /bin:/usr/bin:/usr/local/bin:/opt/perforce/bin:/opt/perforce/sbin
    }
}
EOB

# Generate the server's private key and certificate
tee $SSLDIR/config.txt <<- EOB
C = US           # Country Name - 2 letter code
ST = OH          # ST: State or Province Name - full name
L = Akron        # L: Locality or City Name
O = Danware      # O: Organization or Company Name
OU = Software    # OU = Organization Unit - division or unit
CN = $SERVERDNS  # CN: Common Name (usually the DNS name of the server)
EX = 730         # EX: number of days from today for certificate expiration
UNITS = days     # UNITS: unit multiplier for expiration - "secs", "mins", "hours", or "days"
EOB
sudo -u perforce p4d -Gc

# Start the service
#sudo -u perforce p4dctl start -t p4d $serverName

# Fire up the local Postfix mail server required for Helix GitSwarm
yum install -y postfix
chkconfig postfix on
service postfix start

# Install and reconfigure GitSwarm
gitswarmCfg=/etc/gitswarm/gitswarm.rb
yum install -y helix-gitswarm
sed -r "s|^external_url 'http:\/\/.*'|external_url 'http:\/\/$SERVERDNS'|" $gitswarmCfg | tee $gitswarmCfg
#adjust time_zone line here
gitswarm-ctl reconfigure