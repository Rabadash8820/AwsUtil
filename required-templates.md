# CloudFormation templates required by Danware

1. Main: VPC and internet gateway, S3 buckets
2. Security: Simple AD directory and IAM users/policies
3. Bastions: Bastion hosts in public subnets
4. Messaging: WorkMail and SES with S3 bucket
5. Domains: Route 53 hosted zones
6. Websites: Wordpress web host in public subnet
7. VersionControl: Perforce master server
8. CI/CD: CodePipeline, CodeDeploy, Jenkins servers
8. Database: RDS database
9. Reporting: CloudTrail trails, CloudWatch metrics, SNS topics, and S3 buckets
