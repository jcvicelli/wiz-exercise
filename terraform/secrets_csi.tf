# Secrets Store CSI Driver
resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
}

# AWS Secrets Manager Provider for CSI Driver
resource "helm_release" "secrets_store_csi_driver_provider_aws" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
}

# IAM Role for Service Account (IRSA) for the app to access Secrets Manager
module "secrets_manager_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52.0"

  role_name = "todo-app-secrets-manager-role"

  role_policy_arns = {
    policy = aws_iam_policy.secrets_manager_access.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["wiz-exercise:todo-app-sa"]
    }
  }
}

resource "aws_iam_policy" "secrets_manager_access" {
  name        = "TodoAppSecretsManagerAccess"
  description = "Policy for Todo App to access MongoDB secret in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue"
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.mongodb_auth.arn
      }
    ]
  })
}

# Output the SecretProviderClass YAML (or we could manage it via kubernetes_manifest)
# For this exercise, we'll use a kubernetes_manifest or keep it in k8s/ folder.
# Managing it here allows us to use Terraform variables.

resource "kubernetes_manifest" "mongodb_secret_provider" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "mongodb-secret-provider"
      namespace = "wiz-exercise"
    }
    spec = {
      provider = "aws"
      parameters = {
        objects = yamlencode([
          {
            objectName     = aws_secretsmanager_secret.mongodb_auth.name
            objectType     = "secretsmanager"
            jmesPath = [
              {
                path = "password"
                objectAlias = "password"
              }
            ]
          }
        ])
      }
      secretObjects = [
        {
          secretName = "mongodb-connection-csi"
          type       = "Opaque"
          data = [
            {
              objectName = "password"
              key        = "password"
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.secrets_store_csi_driver]
}
