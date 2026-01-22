# Bootstrapping the Wiz Technical Exercise

This guide explains how to set up the necessary AWS identity trust and infrastructure state backend to enable the CI/CD pipelines.

## Prerequisites

1. **AWS CLI:** Installed and configured with administrator credentials (`aws configure`).
2. **Terraform:** Version 1.10+ installed.
3. **GitHub Repository:** Access to the `jcvicelli/wiz-exercise` repository settings.

---

## Step 1: Provision Identity Trust (OIDC)

This step creates the OpenID Connect (OIDC) provider and the IAM role that GitHub Actions will assume to deploy infrastructure.

1. Navigate to the bootstrap directory:
   ```bash
   cd bootstrap
   ```
2. Initialize and apply the configuration:
   ```bash
   terraform init
   terraform apply
   ```
3. **Note the Role ARN:** The output will include the `GitHubActionsProvisionerRole` ARN.

---

## Step 2: Provision Terraform State Backend

The main infrastructure uses an S3 bucket and DynamoDB table for remote state management. These must be created before the CI/CD pipeline can run.

1. Navigate to the terraform directory:
   ```bash
   cd ../terraform
   ```
2. Since the backend is not yet created, initialize Terraform without a backend:
   ```bash
   terraform init -backend=false
   ```
3. Apply the bootstrap resources only:
   ```bash
   terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_state_lock -target=aws_s3_bucket_versioning.terraform_state -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state -target=aws_s3_bucket_public_access_block.terraform_state
   ```

---

## Step 3: Configure GitHub Secrets

To allow the pipelines to authenticate, add the following secret to your GitHub repository (**Settings > Secrets and variables > Actions**):

- `AWS_ACCOUNT_ID`: Your 12-digit AWS Account ID.

---

## Step 4: Verify and Deploy

Once the bootstrap steps are complete, you can trigger the full deployment:

1. **Push to Main:** Push any change (or merge a PR) to the `main` branch.
2. **Monitor Pipelines:**
   - The **Infrastructure** pipeline will run first to provision EKS, EC2, and S3.
   - The **Application** pipeline will follow to build the container, scan for security issues (Gosec/Trivy), and deploy to EKS.

---

## Cleanup

To destroy all resources created by this exercise:
1. Run `terraform destroy` in the `terraform/` directory.
2. Run `terraform destroy` in the `bootstrap/` directory.
