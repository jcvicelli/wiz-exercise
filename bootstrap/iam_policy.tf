resource "aws_iam_role_policy" "scoped_provisioning_policy" {
  name = "GitHubProvisioningPolicy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NetworkInfrastructure"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:DescribeInternetGateways", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "ComputeInfrastructure"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances", "ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "ec2:DescribeInstanceAttribute", "ec2:ModifyInstanceAttribute",
          "ec2:CreateKeyPair", "ec2:DeleteKeyPair", "ec2:DescribeKeyPairs", "ec2:ImportKeyPair",
          "ec2:DescribeImages",
          "ec2:CreateVolume", "ec2:DeleteVolume", "ec2:AttachVolume", "ec2:DetachVolume", "ec2:DescribeVolumes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster", "eks:UpdateClusterConfig", "eks:UpdateClusterVersion", "eks:ListClusters",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup", "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion",
          "eks:ListNodegroups", "eks:TagResource", "eks:UntagResource",
          "eks:DescribeAddon", "eks:CreateAddon", "eks:DeleteAddon", "eks:UpdateAddon",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "IAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:ListRoles", "iam:TagRole", "iam:UntagRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      {
        Sid    = "ContainerRegistry"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories", "ecr:ListImages", "ecr:PutImage", "ecr:BatchGetImage",
          "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy", "ecr:SetRepositoryPolicy", "ecr:GetRepositoryPolicy", "ecr:DeleteRepositoryPolicy"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "ContainerRegistryAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "StorageAndLogging"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
          "s3:PutBucketVersioning", "s3:GetBucketVersioning", "s3:PutBucketTagging", "s3:GetBucketTagging", "s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock",
          "s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket",
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:PutRetentionPolicy", "logs:ListTagsLogGroup", "logs:TagLogGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "ServerlessAndEvents"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:GetFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:ListTags", "lambda:TagResource", "lambda:UntagResource", "lambda:AddPermission", "lambda:RemovePermission",
          "events:PutRule", "events:DeleteRule", "events:DescribeRule", "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "SecurityConfiguration"
        Effect = "Allow"
        Action = [
          "config:PutConfigRule", "config:DeleteConfigRule", "config:DescribeConfigRules", "config:StartConfigRulesEvaluation",
          "config:PutConfigurationRecorder", "config:DeleteConfigurationRecorder", "config:DescribeConfigurationRecorders", "config:StartConfigurationRecorder", "config:StopConfigurationRecorder",
          "config:PutDeliveryChannel", "config:DeleteDeliveryChannel", "config:DescribeDeliveryChannels"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "LoadBalancing"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "SecretManagement"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "CloudTrail"
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:ListAliases",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:ScheduleKeyDeletion",
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "eu-central-1" }
        }
      }
    ]
  })
}
