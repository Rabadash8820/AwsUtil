# AWS Utility Scripts

## About

These scripts are intended to be general-purpose, for organizations other than Danware to quickly allocate CloudFormation stacks, EC2 instances with `cfn-init` actions, database hosts with SQL schemas, etc.

To check the output of `cloud-init` user data scripts, view `/var/log/cloud-init-output.log` once the instance has started and passed all status checks.  Initiation of automatic updates via `yum-cron` are logged in `/var/log/cron` and actual completed updates are logged in `/var/log/yum.log`.  Initiation of describing an instance's `CloudFormation::Init` metadata via `cfn-hup` is logged in `/var/log/cfn-hup.log`, and the `cfn-init` command that parses and executes this metadata is logged in `/var/log/cfn-init.log`.

## CloudFormation Stack Creation Order

This is the order in which you should create stacks from the various CloudFormation templates in this repository.  Stacks must only be created in Regions that support all of the services used by resources in the stack.

1. Set up services
   - **region-vpc**:  creates a VPC with an Internet Gateway, and may be placed in any Region, any number of times.
   - **main-s3**:  creates an S3 bucket to store logs from other buckets for the organization.  Should only be created once.
   - **main-lambda**:  creates an S3 bucket to store Lambda deployment packages for the organization.  Should only be created once, and must be created _after_ the main-s3 stack so that the bucket can be logged.
   
2. Set up organization directory
   - **active-directory**:  creates a Samba 4 Active Directory Compatible Server (a smaller, cheaper solution to Microsoft Active Directory.  It takes a reference to one of the region-vpc stacks created above as a parameter, and must be placed in the same region as one of those stacks.
   
3. Add utility Lambda functions
   - **region-lookup-lambda**:  creates a Lambda function to return various data about Regions and AMIs that will be used as CustomResources in later stacks.  Should only be created once, and must be created _after_ the main-lambda stack so that the organization's bucket for Lambda packages can be referenced.
   
4. Secure VPCs
   - **bastion-security**: creates security settings (Network ACLs and Security Groups) for a bastion host.  These settings are VPC-specific, so this stack must be created in the same Region as one of the VPC stacks from above, and there should be one of these stacks for every VPC that you wish to protect with a bastion host.
   - **bastion-host**: creates an actual bastion host in a new public subnet in a user-specified Availability Zone.  The subnet uses security resources from the bastion-security stack (so this stack must be created 2nd), and networking resources from one of the region-vpc stacks.  There should be one bastion host in each Availability Zone of the VPCs that you wish to protect.
