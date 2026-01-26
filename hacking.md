# 📘 Playbook: Wiz Technical Exercise Demo

## 1. Kubernetes Workload Verification

**Goal:** Prove the Tier-1 (EKS) front-end is healthy and reachable.

* **List Cluster Resources:**
```bash
kubectl -n wiz-exercise get pods,deployments,services,ingress

```


* **Verify Persistence/Filesystem:**
```bash
# Exec into the pod and read the marker file
kubectl -n wiz-exercise exec -it <pod-name> -- cat /app/wizexercise.txt

```


* **Show Front-end Application:**
* Open your browser and navigate to the **ALB DNS Name** or run:


```bash
curl k8s-wizexerc-todoappi-xxx-xxx.us-west-2.elb.amazonaws.com

```



---

## 2. Tier-2 Connectivity & Secret Management

**Goal:** Demonstrate secure secret retrieval for the MongoDB database.

* **Show Runtime Environment Variables:**
```bash
# Verify the secret is injected from AWS Secrets Manager
kubectl -n wiz-exercise exec -it todo-app-xxx-p7r7g -- env 

```


* **Verify DB Connectivity:**
```bash
# Simple check to see if the app pod can reach MongoDB on port 27017
kubectl -n wiz-exercise exec -it todo-app-xxx-p7r7g -- nc -zv 10.0.1.9 27017

```

* **Verify DB data:**
```bash
# Login to mongodb server
mongosh --username admin --password '{admin_password}' --authenticationDatabase admin
mongosh
showdbs
use go-mongodb
show collections
db.todos.find()

```


---

## 3. Detective Controls & Audit Logging

**Goal:** Show how native AWS tools detect your "intentional" weaknesses.

* **Public S3 Access:**
```bash
# Demonstrate the bucket is open (Intentional Weakness)
curl https://wiz-exercise-mongodb-backups-xxx.s3.us-west-2.amazonaws.com/mongodb-backup-2026-01-26-02-00-23.gz -o backup.gz

gzip -d < backup.gz > db.bson

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

**Goal:** Showcase lateral movement.

### Scenario A: Lateral Movement from Compromised Host

1. **SSH into MongoDB Instance:**
```bash
ssh -i "wiz-exercise-key.pem" ec2-user@ec2-xxx.us-west-2.compute.amazonaws.com

```


2. **Attempt to create new infrastructure:**
```bash
# Attempt to launch another EC2 instance as the compromised role
aws ec2 run-instances --image-id ami-xxxx --instance-type t2.micro

```


* **Result:** Would fail with `AccessDenied` if correct set **IAM Permission Boundaries**.



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


* **Result:** Would fail if you implemented **RBAC** correctly, limiting the pod to its own service account.



### Scenario C: Data Exfiltration

1. **Act as an Unauthenticated Attacker:**
```bash
# Download sensitive data from the misconfigured bucket
curl https://wiz-exercise-mongodb-backups-xxx.s3.us-west-2.amazonaws.com/mongodb-backup-2026-01-26-02-00-23.gz

```
