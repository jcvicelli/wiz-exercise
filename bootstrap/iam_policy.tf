resource "aws_iam_role_policy" "scoped_provisioning_policy" {
  name = "GitHubProvisioningPolicy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteAccessScopedToRegion"
        Effect = "Allow"
        Action = [
          "ec2:*", "ecr:*", "s3:*", "eks:*", "iam:*", "kms:*",
          "dynamodb:*", "secretsmanager:*", "config:*", "events:*", "logs:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" : "us-west-2" }
        }
      }
    ]
  })
}

# Allows Terraform to refresh state without 403s
resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Explicitly required for EKS and IAM role creation
resource "aws_iam_role_policy_attachment" "iam_full" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}
