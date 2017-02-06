# AWS Utility Scripts

These scripts are intended to be general-purpose, for organizations other than Danware to quickly allocate CloudFormation stacks, EC2 instances with cloud-init scripts, database hosts with SQL schemas, etc.

To check the output of one any cloud-init scripts, view `/var/log/cloud-init-output.log` once the instance has started and passed all status checks.  
Initiation of automatic updates via yum-cron are logged in `/var/log/cron` and actual completed updates are logged in `/var/log/yum.log`
