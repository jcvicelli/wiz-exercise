# Wiz Technical Exercise - Implementation Plan

## Architecture Overview

Two-tier web application with intentional security misconfigurations:
- **Tier 1**: Kubernetes cluster (EKS) running containerized Go todo application
- **Tier 2**: EC2 instance running outdated MongoDB with automated backups to public S3
- **DevSecOps**: Full CI/CD with security scanning and OIDC authentication

---

## Step 1: Bootstrap Identity Trust (Manual/OIDC)

### GitHub OIDC Provider
1. **OIDC Provider**: Deploy `aws_iam_openid_connect_provider` for GitHub Actions
2. **Scoped IAM Role**: Create `GitHubActionsRole` with Trust Policy limited to your specific repository
3. **Scoped Policy**: Attach custom policy with least-privilege permissions for:
   - `ec2`: VPC, Subnets, Security Groups, Instances (scoped to specific VPC ID)
   - `eks`: Cluster and NodeGroup management
   - `s3`: CRUD operations for the exercise bucket only
   - `iam`: `PassRole` for EKS/EC2 service roles only
   - `ecr`: Container registry operations
   - `logs`: CloudWatch log group management
   - `lambda`: Function deployment for backup automation
   - `events`: EventBridge rule management
   - `config`: AWS Config rule deployment

---

## Step 2: Network Foundation (VPC)

### VPC Configuration
1. **Module**: Use `terraform-aws-modules/vpc/aws`
2. **Subnets**:
   - 2 Public Subnets (for MongoDB VM and ALB)
   - 2 Private Subnets (for EKS worker nodes)
   - Enable NAT Gateway for private subnet egress
3. **Detective Control - VPC Flow Logs**:
   - Enable VPC Flow Logs streaming to CloudWatch Logs
   - Retention period: 7 days minimum
   - Captures ALL traffic (accepted and rejected)

---

## Step 3: Database & Storage (Tier 2)

### S3 Bucket for MongoDB Backups
1. **Module**: Use `terraform-aws-modules/s3-bucket/aws`
2. **Intentional Misconfigurations**:
   - Disable all public access blocks (`block_public_acls = false`, etc.)
   - Attach bucket policy granting `s3:GetObject` and `s3:ListBucket` to `Principal: "*"`
   - Enable versioning for backup history
3. **Tagging**: Add tags identifying this as intentionally misconfigured

### MongoDB EC2 Instance
1. **Module**: Use `terraform-aws-modules/ec2-instance/aws`
2. **AMI Selection**: 
   - Use Ubuntu 20.04 LTS or similar (1+ year outdated)
   - Document the AMI ID and age in your presentation
3. **MongoDB Version**: 
   - Install MongoDB 4.4 or similar (1+ year outdated)
   - Document why this version is vulnerable
4. **Network Configuration**:
   - Deploy in Public Subnet (assign public IP)
   - Security Group rules:
     - **SSH port 22**: Open to `0.0.0.0/0` (INTENTIONAL WEAKNESS)
     - **MongoDB port 27017**: Restricted to EKS private subnet CIDRs only
     - Egress: Allow all outbound
5. **IAM Role - Intentional Weakness**:
   - Attach overly permissive IAM role allowing:
     - `ec2:RunInstances` (ability to create VMs)
     - `ec2:CreateVolume`, `ec2:AttachVolume`
     - S3 write access to backup bucket
   - Document why this violates least privilege
6. **MongoDB Configuration**:
   - Enable authentication with username/password
   - Create `tododb` database with dedicated user
   - Configure to bind to all interfaces but secured by security group
7. **User Data Script**:
   - Install outdated MongoDB version
   - Configure authentication
   - Create admin and application users
   - Start MongoDB service

### Backup Automation
1. **Lambda Function**:
   - Python/Bash script to perform mongodump
   - Use EC2 instance metadata or SSM to locate MongoDB instance
   - Upload compressed backup to S3 bucket
   - Grant Lambda role permissions for EC2 describe and S3 write
2. **EventBridge Scheduled Rule**:
   - Trigger Lambda function daily (e.g., 2 AM UTC)
   - Document backup retention strategy
3. **Validation**:
   - Ensure backups appear in S3 bucket
   - Verify public read access works

---

## Step 4: Compute Cluster (Tier 1)

### EKS Cluster
1. **Module**: Use `terraform-aws-modules/eks/aws`
2. **Configuration**:
   - Deploy in private subnets
   - Enable control plane logging: `["api", "audit", "authenticator", "controllerManager", "scheduler"]`
   - Version: Use latest stable EKS version
3. **Node Group**:
   - Deploy in private subnets
   - Instance type: t3.medium or similar
   - Desired capacity: 2 nodes minimum
4. **Access Management**:
   - Configure `access_entries` mapping `GitHubActionsRole` to `AmazonEKSClusterAdminPolicy`
   - Enable kubectl access for CI/CD pipeline

### Container Registry
1. **ECR Repository**:
   - Create private ECR repository for todo app
   - Enable image scanning on push
   - Configure lifecycle policy (keep last 10 images)

### AWS Load Balancer Controller
1. **Installation**:
   - Deploy AWS Load Balancer Controller to EKS cluster
   - Configure IAM role for service account (IRSA)
   - Enable for Ingress resource creation

---

## Step 5: Application Container

### Dockerfile Modifications
1. **Base Image**: Use official Go image for build stage
2. **Add wizexercise.txt**:
   - Create file containing your name
   - Copy into container image during build
   - Document location (e.g., `/app/wizexercise.txt`)
3. **Multi-stage Build**:
   - Stage 1: Build the Go application
   - Stage 2: Create minimal runtime image
   - Copy binary and wizexercise.txt to final image
4. **Validation Method**:
   - Document kubectl command to exec into pod and cat the file
   - Include in presentation demo script

---

## Step 6: Kubernetes Manifests

### Namespace
1. Create dedicated namespace (e.g., `wiz-exercise`)

### Secret for MongoDB Connection
1. **Kubernetes Secret**:
   - Store MongoDB connection string as environment variable
   - Format: `mongodb://todoapp:TodoApp2025!@MONGODB_PRIVATE_IP:27017/tododb`
   - Encode credentials securely

### Deployment
1. **Deployment Manifest**:
   - Reference ECR image with specific tag
   - Mount MongoDB connection string from Secret as environment variable
   - Set resource requests/limits
   - Configure health/readiness probes

### ServiceAccount & RBAC - Intentional Weakness
1. **ServiceAccount**: Create dedicated service account for the pod
2. **ClusterRoleBinding - INTENTIONAL WEAKNESS**:
   - Bind the service account to `cluster-admin` ClusterRole
   - Document why this is dangerous (pod can control entire cluster)
   - Explain blast radius in presentation

### Service
1. **ClusterIP Service**:
   - Expose application on port 80/8080
   - Route traffic to pod selector

### Ingress
1. **Ingress Resource**:
   - Use AWS ALB Ingress annotations
   - Configure public-facing Application Load Balancer
   - Set up health check path
   - Enable internet-facing scheme

---

## Step 7: Cloud Native Security Controls

### Detective Control - AWS Config
1. **AWS Config Service**:
   - Enable AWS Config in the region
   - Configure configuration recorder and delivery channel
2. **Config Rules**:
   - Deploy `s3-bucket-public-read-prohibited` rule
   - Deploy `ec2-security-group-attached-to-eni` rule
   - Set rules to detective mode (don't auto-remediate)
   - Document findings in presentation

### Preventative Control - IAM Permission Boundary
1. **Permission Boundary**:
   - Create IAM permission boundary policy
   - Apply to MongoDB instance role to limit maximum permissions
   - Demonstrate that even with overly permissive inline policies, boundary restricts actions
   - **Alternative**: Use AWS Organizations SCP if available

### Control Plane Audit Logging
1. **CloudTrail**:
   - Enable CloudTrail for all management events
   - Log to dedicated S3 bucket
   - Enable log file validation
2. **EKS Audit Logs**:
   - Already enabled in Step 4 (control plane logging)
   - Stream to CloudWatch Logs
3. **MongoDB Access Logs**:
   - Configure MongoDB audit logging (if supported in version)
   - Or document limitations of outdated version

---

## Step 8: CI/CD Pipeline A - Infrastructure (IaC)

### GitHub Actions Workflow: `infra.yml`
1. **Trigger**: Push to `main` branch, paths: `terraform/**`
2. **Authentication**: Use `aws-actions/configure-aws-credentials` with OIDC
3. **Security Scanning**:
   - Run `bridgecrewio/checkov-action` to scan Terraform code
   - Fail pipeline on HIGH/CRITICAL findings (optional: set to warning for demo)
   - Upload results as workflow artifact
4. **Terraform Steps**:
   - `terraform init` with S3 backend
   - `terraform plan` and save plan file
   - `terraform apply -auto-approve` (only on main branch)
5. **Outputs**:
   - Export EKS cluster name
   - Export MongoDB private IP
   - Export S3 bucket name

---

## Step 9: CI/CD Pipeline B - Application (Container Build & Deploy)

### GitHub Actions Workflow: `app.yml`
1. **Trigger**: Push to `main` branch, paths: `app/**`, `Dockerfile`
2. **Authentication**: Use `aws-actions/configure-aws-credentials` with OIDC
3. **Container Build**:
   - Build Docker image with wizexercise.txt embedded
   - Tag with commit SHA and `latest`
4. **Security Scanning**:
   - Run `aquasecurity/trivy-action` to scan container image
   - Scan for vulnerabilities, misconfigurations, and secrets
   - Fail on HIGH/CRITICAL CVEs (optional: warning mode for demo)
   - Upload SARIF results to GitHub Security tab
5. **Push to ECR**:
   - Authenticate to Amazon ECR
   - Push image with both tags
6. **Deploy to EKS**:
   - Update kubeconfig using aws-cli
   - Apply Kubernetes manifests with `kubectl apply -f k8s/`
   - Verify deployment rollout status
   - Output ALB endpoint URL

---

## Step 10: Optional Simulation - Attack Scenarios

### Simulated Attack 1: S3 Data Exfiltration
1. Demonstrate public access to S3 bucket
2. Show MongoDB backup data readable by anyone
3. Show how AWS Config detects this misconfiguration

### Simulated Attack 2: SSH Brute Force
1. Document evidence of SSH access attempts in VPC Flow Logs
2. Show CloudTrail logs of authentication attempts (if GuardDuty enabled)
3. Demonstrate detective control alerting

### Simulated Attack 3: Kubernetes Privilege Escalation
1. Exec into pod with cluster-admin role
2. Demonstrate ability to list secrets across all namespaces
3. Show `kubectl auth can-i --list` output
4. Explain how EKS audit logs capture this activity

### Simulated Attack 4: Overly Permissive IAM
1. SSH into MongoDB instance
2. Use instance metadata to assume IAM role
3. Demonstrate ability to create EC2 instances
4. Show CloudTrail evidence of unauthorized actions

---

## Step 11: VCS/SCM Repository Structure

### Repository Organization
```
wiz-exercise/
├── .github/
│   └── workflows/
│       ├── infra.yml
│       └── app.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── ec2.tf
│   ├── eks.tf
│   ├── s3.tf
│   ├── lambda.tf
│   ├── iam.tf
│   └── security-controls.tf
├── app/
│   ├── Dockerfile
│   ├── wizexercise.txt
│   └── (Go application files)
├── k8s/
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── clusterrolebinding.yaml
│   └── ingress.yaml
├── lambda/
│   └── mongodb-backup.py
└── README.md
```

### Repository Security Controls
1. **Branch Protection**:
   - Require pull request reviews before merging
   - Require status checks to pass (Checkov, Trivy)
   - Require signed commits (optional)
2. **Dependabot**:
   - Enable for Terraform and Docker dependencies
   - Auto-create PRs for security updates
3. **GitHub Advanced Security** (if available):
   - Enable secret scanning
   - Enable code scanning with CodeQL
   - Review security alerts tab

---

## Validation Checklist

### Infrastructure
- [ ] VPC with public and private subnets created
- [ ] VPC Flow Logs streaming to CloudWatch
- [ ] MongoDB EC2 instance running in public subnet
- [ ] SSH accessible from internet (port 22)
- [ ] MongoDB accessible only from EKS subnets (port 27017)
- [ ] MongoDB using outdated version (4.4 or older)
- [ ] EC2 instance using outdated Ubuntu AMI (1+ year old)
- [ ] EC2 instance has overly permissive IAM role
- [ ] S3 bucket publicly readable and listable
- [ ] Daily backup Lambda function triggered by EventBridge
- [ ] Backup files appearing in S3 bucket
- [ ] EKS cluster deployed in private subnets
- [ ] EKS control plane logs enabled (api, audit, authenticator)
- [ ] ECR repository created with scanning enabled

### Application
- [ ] Container image built with wizexercise.txt containing your name
- [ ] Image scanned by Trivy in CI/CD pipeline
- [ ] Image pushed to ECR successfully
- [ ] Kubernetes deployment running in private subnet
- [ ] Pod has cluster-admin ClusterRoleBinding (intentional weakness)
- [ ] MongoDB connection configured via environment variable
- [ ] Application accessible via public ALB endpoint
- [ ] Can demonstrate todo app CRUD operations
- [ ] Can verify data persists in MongoDB

### Security Controls
- [ ] AWS Config enabled with at least one rule
- [ ] Permission boundary or preventative control implemented
- [ ] CloudTrail logging all management events
- [ ] Checkov scanning Terraform in pipeline
- [ ] Trivy scanning container images in pipeline
- [ ] GitHub branch protection enabled
- [ ] Repository security features configured

### Demo Preparation
- [ ] Can demonstrate kubectl access to cluster
- [ ] Can exec into pod and show wizexercise.txt file
- [ ] Can show MongoDB authentication working
- [ ] Can access web application and perform CRUD operations
- [ ] Can show public S3 bucket access
- [ ] Can show VPC Flow Logs in CloudWatch
- [ ] Can show AWS Config findings
- [ ] Can explain each intentional misconfiguration
- [ ] Can demonstrate security tool detection (Config/CloudTrail)

---

## Presentation Structure (45 Minutes)

### Introduction (5 minutes)
- Your background and approach to the exercise
- High-level architecture overview

### Live Demo (20 minutes)
- Walk through deployed infrastructure
- Demonstrate working application (CRUD operations)
- Show wizexercise.txt in running container
- Demonstrate kubectl commands
- Show MongoDB connectivity and authentication
- Demonstrate public S3 bucket access

### Security Analysis (15 minutes)
- Discuss each intentional misconfiguration:
  - Outdated OS and MongoDB versions
  - Public SSH exposure
  - Overly permissive IAM roles
  - Cluster-admin Kubernetes role
  - Public S3 bucket
- Explain potential attack scenarios and impact
- Demonstrate security controls detecting issues:
  - AWS Config findings
  - VPC Flow Logs evidence
  - EKS audit logs
  - CloudTrail events

### DevSecOps Pipeline (5 minutes)
- Show CI/CD workflow files
- Demonstrate Checkov/Trivy scan results
- Explain shift-left security approach
- Show OIDC authentication (no secrets)

### Questions & Discussion (15 minutes)
- Panel questions
- Discussion about Wiz capabilities

---

## Key Talking Points for Principal SE Role

### Customer Empathy
- "This reflects what I see in real customer environments..."
- "Organizations often have legacy systems like this outdated MongoDB..."
- "The cluster-admin role is a common misconfiguration I've encountered..."

### Risk Communication
- Quantify blast radius of each misconfiguration
- Explain lateral movement opportunities
- Discuss compliance implications (PCI-DSS, SOC 2, GDPR)

### Wiz Value Proposition (Research Before Presentation)
- How Wiz CSPM would detect these misconfigurations
- How Wiz's graph-based approach shows attack paths
- How Wiz prioritizes risks based on context
- How Wiz integrates with CI/CD pipelines

### Architectural Decisions
- Explain why OIDC over static credentials
- Justify use of AWS verified modules
- Discuss trade-offs in security control placement
- Explain shift-left vs. runtime detection balance

---

## Task Output Summary

- **Secrets in Repository**: 0 (Fully OIDC-based authentication)
- **IaC Tool**: Terraform with AWS Verified Modules
- **CI/CD Platform**: GitHub Actions
- **Security Scanning**: Checkov (IaC), Trivy (Container)
- **Compliance**: Audit logs enabled across VPC, EKS, CloudTrail, AWS Config
- **Intentional Weaknesses**: 
  - Public SSH (port 22 to 0.0.0.0/0)
  - Outdated Ubuntu OS (1+ year old)
  - Outdated MongoDB (version 4.4 or older)
  - Overly permissive EC2 IAM role (can create VMs)
  - Cluster-admin Kubernetes role
  - Public readable/listable S3 bucket
- **Security Controls**:
  - Detective: VPC Flow Logs, AWS Config, CloudTrail, EKS Audit Logs
  - Preventative: IAM Permission Boundary (or SCP)
- **Container Image**: Custom-built with wizexercise.txt embedded
