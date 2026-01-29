module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.9.0"

  name = "wiz-exercise-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  public_subnet_tags = {
    "kubernetes.io/role/elb"                 = "1"
    "kubernetes.io/cluster/wiz-exercise-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"        = "1"
    "kubernetes.io/cluster/wiz-exercise-eks" = "shared"
  }


  enable_nat_gateway = true
  single_nat_gateway = true # Cost optimization for exercise

  # DNS Support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs (Detective Control)
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = 7

  tags = {
    Environment = "dev"
  }
}
