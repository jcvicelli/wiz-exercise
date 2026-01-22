# Optional Simulation - Attack Scenarios

## Simulated Attack 1: S3 Data Exfiltration
1. Demonstrate public access to S3 bucket
2. Show MongoDB backup data readable by anyone
3. Show how AWS Config detects this misconfiguration

## Simulated Attack 2: SSH Brute Force
1. Document evidence of SSH access attempts in VPC Flow Logs
2. Show CloudTrail logs of authentication attempts (if GuardDuty enabled)
3. Demonstrate detective control alerting

## Simulated Attack 3: Kubernetes Privilege Escalation
1. Exec into pod with cluster-admin role
2. Demonstrate ability to list secrets across all namespaces
3. Show `kubectl auth can-i --list` output
4. Explain how EKS audit logs capture this activity

## Simulated Attack 4: Overly Permissive IAM
1. SSH into MongoDB instance
2. Use instance metadata to assume IAM role
3. Demonstrate ability to create EC2 instances
4. Show CloudTrail evidence of unauthorized actions
