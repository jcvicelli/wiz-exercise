module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5.0"

  name = "wiz-exercise-vpc"
  cidr = var.vpc_cidr

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true # Cost optimization for exercise

  # DNS Support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs (Detective Control)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_traffic_type                = "ALL"
  flow_log_max_aggregation_interval    = 60
  flow_log_cloudwatch_log_group_retention_in_days = 7

  tags = {
    Environment = "dev"
  }
}
