data "http" "github_ips" {
  url = "https://api.github.com/meta"
  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

locals {
  github_cidrs  = jsondecode(data.http.github_ips.response_body).actions
  home_ip_cidrs = ["80.144.223.23/32"]
  allowed_cidrs = distinct(concat(local.github_cidrs, local.home_ip_cidrs))
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = "wiz-exercise-eks"
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  endpoint_private_access = true
  public_access_cidrs     = local.allowed_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      metadata_options = {
        http_put_response_hop_limit = 2
        http_endpoint               = "enabled"
        http_tokens                 = "required"
      }
    }
  }

  # Cluster logging (Detective Control)
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Modern Access Entries (No aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  access_entries = merge(
    {
      github_actions = {
        principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsProvisionerRole"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    var.admin_user_name != "" ? {
      cluster_admin = {
        principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.admin_user_name}"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    } : {}
  )

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "vpc-cni"
  addon_version = "v1.18.0" # Use latest
}

data "aws_caller_identity" "current" {}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
