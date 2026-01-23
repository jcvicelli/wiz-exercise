Using LLM to bootstrap:
- defaults to insecure behaviour (ex. hardcoded secrets, over provisioned roles)
- oversimplified k8s yamls (no resource limits, no network security)
- insisted in saving audit logs in the backup bucket
- Outdate versions of resources (terraform, k8s, for example)
-
First big terraform apply done manually, github actions didn't like it
Terraform 