# platform-pacerpro

# Automated Incident Remediation: Sumo Logic & AWS
## Project Overview
This project implements a "Self-Healing" infrastructure pipeline. It automatically detects high latency in response time from API endpoints using Sumo Logic and triggers an automated remediation workflow using AWS Lambda to reboot the failing EC2 instance. It also notifies the operations team via AWS SNS.

## Workflow:

- Ingest: Structured logs (.json) are ingested into Sumo Logic.

- Detect: A Sumo Logic Monitor runs a query to identify if the /api/data endpoint exceeds 3.0s response time more than 5 times in 10 minutes.

- Trigger: The Monitor fires a Webhook to an AWS Lambda Function URL.

- Remediate: The Lambda function (Python) executes ec2.reboot_instances.

- Notify: The Lambda publishes a "Success" message to an SNS Topic (email).

## Prerequisites
AWS CLI: Installed and configured.

Terraform: Installed (v1.0+).

Sumo Logic Account: (Free tier or standard).

Python 3.14: (For the Lambda runtime).

### Configure AWS Credentials
Before running Terraform, ensure your local environment is authenticated with AWS.

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Default region name (e.g., us-east-1)
# Default output format (json)
```
## Infrastructure Deployment (Terraform)
This project uses Infrastructure as Code (IaC) to provision the EC2 instance, Lambda function, SNS Topic, and strict IAM policies.

### Initialize Terraform

```bash
terraform init
```
### Format & Validate Terraform
```bash
terraform fmt
terraform validate
```
### Deploy Resources

```bash
terraform apply
#Type yes to confirm.
```

### Capture the Webhook URL 
After the deployment finishes, Terraform (or the AWS Console) will provide the Function URL.

If using Console: Go to Lambda -> rebooter_publisher -> Configuration -> Function URL.

Copy this URL. You will need it for Sumo Logic.

## Sumo Logic Configuration
### Step A: Log Ingestion (Simulation)
> Since this is a demo environment without live traffic, we simulate log data by uploading a JSON file.

Generate/Create Logs: Create a logs.json file with entries where response_time_sec > 3.0

Upload:

- Go to Manage Data -> Collection -> Setup Wizard -> Upload Files.

- Upload logs.json.

- Source Category: uploads/other

### Step B: Create the Webhook Connection
This bridges Sumo Logic to AWS.

- Go to Manage Data -> Monitoring -> Connections.

- Click Add -> Webhook.

- Name: EC2 Rebooter.

- URL: Paste the Lambda Function URL you copied in Section 2.

> Payload: (Default is fine; the Lambda ignores the payload content).

- Click Save.

### Step C: Configure the Monitor (Alert)
Go to Log Search and run this query to verify your data:

```sql
_sourceCategory=uploads/other
| where (response_time_sec > 3.0) and (url == "/api/data" )
```

#### Monitor Configuration

- Detection Method: Static

- Trigger Type: Critical

- Alert Condition: Alert when result count is > 5.

- Time Range: Within 10 Minutes.

- Notifications:

  - Change "Email" to Connection.

  - Select EC2 Rebooter.

- Click Save.

## Security & IAM
**Least Privilege:** The current IAM Role for the Lambda function is scoped strictly to ec2:RebootInstances and sns:Publish on specific ARNs only.

> **NOTE** <br>
> - For the scope of this demonstration, the Lambda Function URL is configured with AuthType: NONE to allow seamless integration with the Sumo Logic Webhook. <br>
> - In a Production Environment, I would secure this by creating a dedicated IAM Role for Sumo Logic.

## Cleanup
To avoid incurring AWS costs, destroy the infrastructure when finished

```bash
terraform destroy
```