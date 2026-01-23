# Project: Wiz Technical Exercise (jcvicelli/wiz-exercise)
# Persona: Principal SRE / Security Architect

## Behavioral Rules
- Be extremely concise. Code first, explanations only if requested.
- No documentation generation. No markdown intros/outros.
- Limit inline code comments to 1 line for complex logic only.

## Core Project Details
- Repository: jcvicelli/wiz-exercise
- Region: eu-central-1 (Frankfurt)
- Terraform: v1.10+
- AWS Provider: v6.0+

## Elite Security Constraints
- ZERO static AWS credentials (OIDC for GitHub Actions).
- IAM Trust Policy: Bound strictly to `repo:jcvicelli/wiz-exercise:*`.
- Modern EKS Access Entries (No legacy aws-auth ConfigMap).
- Runtime Secrets: AWS Secrets Manager.
- Intentional Weaknesses: Public S3 bucket & MongoDB on Public EC2 for Wiz discovery.

## Todos
todo 1: Dynamic Secret Creation in CI/CD (Better)
Remove secret.yaml from repo - Don't commit secrets to git
In app.yml workflow, fetch password from AWS Secrets Manager - After MongoDB is created
Use kubectl create secret - Dynamically create the K8s secret with actual password
Then apply deployment - Deployment references the secret you just created

todo 2: Improve k8s manifests
Ingress has no TLS configuration - Currently HTTP only, no HTTPS - acceptable for exercise but should be noted
No network policies defined - Could add NetworkPolicy to restrict pod-to-pod and pod-to-external traffic
No pod disruption budget - With 2 replicas, should consider PDB for high availability demo
Health check paths assumed to exist - Verify the Go todo app actually has /healthz endpoint or change to /
Missing AWS Load Balancer Controller installation steps - The Ingress won't work without the controller installed in the cluster
Image reference uses placeholder - AWS_ACCOUNT_ID placeholder in deployment.yaml - ensure app.yml workflow sed command actually replaces this
No pod security standards applied - Consider adding security context, running as non-root user, read-only filesystem
Missing resource limits completion - Ensure CPU and memory limits are fully specified, not truncated
GitHubActionsProvisionerRole has k8s cluster admin, verify if it's not overkill

todo 3: improve lambda backup
Issue: lambda.tf line 67-70 - Still only has BACKUP_BUCKET, missing SECRET_NAME

todo 4: improve providers.tf
Issue: providers.tf (document 19) is missing critical providers that are used in your code
Task: Add missing provider requirements

tls provider (used in ec2.tf for key generation)
local provider (used in ec2.tf for SSH key file)
random provider (used in s3.tf and secrets.tf)
archive provider (used in lambda.tf)

todo 5: fix app.yml pipeline
Issue: app.yml line 51 runs kubectl but kubectl isn't installed on ubuntu-latest by default
