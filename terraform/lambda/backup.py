import datetime
import json
import os
import time

import boto3


def lambda_handler(event, context):
    ec2 = boto3.client("ec2")
    ssm = boto3.client("ssm")
    secrets = boto3.client("secretsmanager")

    bucket_name = os.environ["BACKUP_BUCKET"]
    secret_name = os.environ["SECRET_NAME"]

    # Get Credentials
    try:
        secret_value = secrets.get_secret_value(SecretId=secret_name)
        secret_json = json.loads(secret_value["SecretString"])
        admin_password = secret_json["admin_password"]
        print("Successfully retrieved MongoDB credentials")
    except Exception as e:
        print(f"Failed to retrieve secret: {str(e)}")
        return

    # Find MongoDB Instance
    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Name", "Values": ["wiz-exercise-mongodb"]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ]
    )

    instances = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            instances.append(instance["InstanceId"])

    if not instances:
        print("No MongoDB instance found")
        return

    instance_id = instances[0]
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    backup_file = f"mongodb-backup-{timestamp}.gz"

    # Command to run on EC2
    # Using 'mongodump --archive --gzip' to stream

    command = f"mongodump --username admin --password '{admin_password}' --authenticationDatabase admin --db tododb --archive --gzip | aws s3 cp - s3://{bucket_name}/{backup_file}"

    # Mask password in logs
    masked_command = command.replace(admin_password, "*****")
    print(f"Sending command to {instance_id}: {masked_command}")

    ssm_response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [command]},
    )

    return {"statusCode": 200, "body": str(ssm_response)}
