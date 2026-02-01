import json
import boto3
import os

print('Loading function')
ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))

    instance = os.environ.get('INSTANCE_ID')
    sns_arn = os.environ.get('SNS_TOPIC_ARN')

    ec2_response = ec2.reboot_instances(
    InstanceIds=[
        instance,
    ],
)
    message = f"Successfully rebooted {instance}"
    print(message)

    sns_response = sns.publish(
    TopicArn=sns_arn,
    Message=message,
    Subject='From Lambda: Rebooted VM',
)