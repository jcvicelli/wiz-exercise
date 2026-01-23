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


---

# 📘 Playbook: Wiz Technical Exercise Demo

## 1. Kubernetes Workload Verification

**Goal:** Prove the Tier-1 (EKS) front-end is healthy and reachable.

* **List Cluster Resources:**
```bash
kubectl get pods,deployments,services,ingress -n <your-namespace>

```


* **Verify Persistence/Filesystem:**
```bash
# Exec into the pod and read the marker file
kubectl exec -it <pod-name> -- cat /app/wizexercise.txt

```


* **Show Front-end Application:**
* Open your browser and navigate to the **ALB DNS Name** or run:


```bash
curl -I <alb-dns-endpoint>

```



---

## 2. Tier-2 Connectivity & Secret Management

**Goal:** Demonstrate secure "Elite" secret retrieval for the MongoDB database.

* **Show Runtime Environment Variables:**
```bash
# Verify the secret is injected from AWS Secrets Manager
kubectl exec -it <pod-name> -- env | grep MONGO

```


* **Verify DB Connectivity:**
```bash
# Simple check to see if the app pod can reach MongoDB on port 27017
kubectl exec -it <pod-name> -- nc -zv <mongodb-ec2-ip> 27017

```



---

## 3. Detective Controls & Audit Logging

**Goal:** Show how native AWS tools detect your "intentional" weaknesses.

* **Public S3 Access:**
```bash
# Demonstrate the bucket is open (Intentional Weakness)
curl https://<bucket-name>.s3.us-west-2.amazonaws.com/backup.zip -o backup.zip

```


* **AWS Config Findings:**
* **Console:** Services > Config > Resources.
* Filter for `AWS::S3::Bucket` or `AWS::EC2::SecurityGroup`.
* **Show:** "Non-compliant" status for the public S3 bucket and the wide-open DB security group.


* **VPC Flow Logs (SSH Traffic):**
* **Console:** CloudWatch > Logs Insights.
* **Query:**
```sql
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter dstPort = 22
| sort @timestamp desc

```




* **CloudTrail (MongoDB Actions):**
* **Console:** CloudTrail > Event History.
* **Filter:** `Event name: RunInstances` or `TerminateInstances`.
* **Show:** The specific IAM user or OIDC role that provisioned the EC2 instance.



---

## 4. 🧨 Attack Simulation (Optional Bonus)

**Goal:** Showcase how preventative controls (IAM Boundaries) stop lateral movement.

### Scenario A: Lateral Movement from Compromised Host

1. **SSH into MongoDB Instance:**
```bash
ssh -i <key.pem> ubuntu@<mongodb-public-ip>

```


2. **Attempt to create new infrastructure:**
```bash
# Attempt to launch another EC2 instance as the compromised role
aws ec2 run-instances --image-id ami-xxxx --instance-type t2.micro

```


* **Result:** Should fail with `AccessDenied` due to **IAM Permission Boundaries**.



### Scenario B: Privilege Escalation in Kubernetes

1. **Exec into a Front-end Pod:**
```bash
kubectl exec -it <pod-name> -- /bin/sh

```


2. **Try to steal cluster secrets:**
```bash
# Attempt to list all secrets in the cluster
kubectl get secrets --all-namespaces

```


* **Result:** Should fail if you implemented **RBAC** correctly, limiting the pod to its own service account.



### Scenario C: Data Exfiltration

1. **Act as an Unauthenticated Attacker:**
```bash
# Download sensitive data from the misconfigured bucket
wget http://<bucket-name>.s3.us-west-2.amazonaws.com/customer_list.csv

```
