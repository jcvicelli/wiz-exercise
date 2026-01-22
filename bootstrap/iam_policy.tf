resource "aws_iam_role_policy" "scoped_provisioning_policy" {
  name = "GitHubProvisioningPolicy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:*", "s3:*", "eks:*", "iam:CreateServiceLinkedRole",
          "iam:GetRole", "iam:PassRole", "secretsmanager:*", "kms:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion": "eu-central-1" }
        }
      }
    ]
  })
}
