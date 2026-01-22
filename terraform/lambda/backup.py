import boto3
import os
import datetime
import time

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    ssm = boto3.client('ssm')
    
    bucket_name = os.environ['BACKUP_BUCKET']
    
    # Find MongoDB Instance
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Name', 'Values': ['wiz-exercise-mongodb']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instances.append(instance['InstanceId'])
            
    if not instances:
        print("No MongoDB instance found")
        return
        
    instance_id = instances[0]
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    backup_file = f"mongodb-backup-{timestamp}.gz"
    
    # Command to run on EC2
    # 1. Dump to stdout
    # 2. Gzip
    # 3. Stream to S3 (using instance's role)
    # Note: mongodump might not be in path for root/ssm-user, specifying full path or assuming standard
    # Using 'mongodump --archive --gzip' to stream
    
    # We need to use the admin user we created
    # User: admin, Pass: AdminPassword2025!
    
    command = f"mongodump --username admin --password 'AdminPassword2025!' --authenticationDatabase admin --archive | gzip | aws s3 cp - s3://{bucket_name}/{backup_file}"
    
    print(f"Sending command to {instance_id}: {command}")
    
    ssm_response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={'commands': [command]}
    )
    
    return {
        'statusCode': 200,
        'body': str(ssm_response)
    }
