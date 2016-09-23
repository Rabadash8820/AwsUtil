#!/bin/bash

echo
echo Beginning setup of a Perforce Helix master server!

# Define constants
SERVERNAME=danware                  # must not contain spaces    
P4SERVERDIR=/opt/perforce/servers	# must not contain spaces
P4ROOTDIR=$P4SERVERDIR/$SERVERNAME  # must not contain spaces
FILESDIR=$P4ROOTDIR/files           # must not contain spaces
SSLDIR=$P4ROOTDIR/ssl               # must not contain spaces
yum install -y curl > NUL           # should already be installed in Amazon Linux AMIs
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ:0:-1}
SERVERDNS=p4.danvicarel.com

# Add a newline to the ec2-user prompt string
echo PS1="\"\\n\$PS1\"">> /home/ec2-user/.bashrc

# Update all packages
echo
echo Updating all YUM packages...
yum update -y > NUL

# Install Perforce packages
# The RHEL/7 part of the baseurl should be replaced with
# the latest RHEL version that both Amazon and Perforce support
echo
echo Adding the Perforce YUM repo as follows:
rpm -import https://package.perforce.com/perforce.pubkey
tee /etc/yum.repos.d/perforce.repo <<- EOB
[perforce]
name=Perforce
baseurl=http://package.perforce.com/yum/rhel/7/x86_64
enabled=1
gpgcheck=1
EOB
echo
echo Installing Perforce Helix...
yum install -y helix-p4d > NUL

# ***** UNCOMMENT IF NECESSARY *****
# echo Formatting drives...
# # Format EBS volumes
# dev1=/dev/sdb     # must not contain spaces
# dbLbl=p4db        # must not contain spaces
# chkptLbl=p4chkpt
# parted -s $dev1 mktable gpt
# parted -s -a optimal $dev1 mkpart primary xfs 0% 100%
# parted -s $dev1 name 1 $dbLbl
# yum install -y xfsprogs > NUL     # should already be installed in Amazon Linux AMIs
# mkfs -t xfs "$dev1"1
# xfs_admin -L $dbLbl "$dev1"1

# Make directories for the server, owned by new "perforce" user
echo Adding server directories...
mkdir -p $FILESDIR $SSLDIR
chown -R perforce:perforce $P4ROOTDIR
chmod 700 $SSLDIR

# Set up automatic mounts (for this and all future reboots)
echo Mounting the shared filesystem for versioned files...
efsID=fs-1768925e
echo "${AZ}.${efsID}.efs.${REGION}.amazonaws.com:/ $FILESDIR nfs4 defaults,vers=4.1,noresvport 0 0" >> /etc/fstab
yum install -y nfs-utils  > NUL   # should already be installed in Amazon Linux AMIs
mount -a -t nfs4

# Configure the Perforce server daemon
echo Configuring the Danware server daemon as follows:
journalPath=$P4ROOTDIR/journal.live   # must not contain spaces
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
echo
echo Configuring SSL certificates for the server as follows:
tee $SSLDIR/config.txt <<- EOB
C = US                  # Country Name - 2 letter code
ST = OH                 # ST: State or Province Name - full name
L = Akron               # L: Locality or City Name
O = Danware             # O: Organization or Company Name
OU = Software           # OU = Organization Unit - division or unit
CN = $SERVERDNS         # CN: Common Name (usually the DNS name of the server)
EX = 730                # EX: number of days from today for certificate expiration
UNITS = days            # UNITS: unit multiplier for expiration - "secs", "mins", "hours", or "days"
EOB
sudo -u perforce p4d -Gc

# Start the service
echo
echo Starting the Danware server...
#sudo -u perforce p4dctl start -t p4d $serverName

# Fire up the local Postfix mail server required for Helix GitSwarm
echo
echo Installing postfix for GitSwarm...
yum install -y postfix > NUL
service postfix start
chkconfig postfix on

# Install and reconfigure GitSwarm
echo Installing Perforce Helix GitSwarm...
gitswarmCfg=/etc/gitswarm/gitswarm.rb
yum install -y helix-gitswarm > NUL
sed -ir "s|^external_url 'http:\/\/.*'|external_url 'http:\/\/$SERVERDNS'|" $gitswarmCfg
sed -ir "s|^# gitlab_rails\['time_zone'\] = 'UTC'|gitlab_rails['time_zone'] = 'EST'|" $gitswarmCfg
gitswarm-ctl reconfigure
