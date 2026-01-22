module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "wiz-exercise-eks"
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

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
    }
  }

  # Cluster logging (Detective Control)
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Modern Access Entries (No aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    github_actions = {
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsProvisionerRole"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

data "aws_caller_identity" "current" {}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
