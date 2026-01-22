# --- MongoDB EC2 Role (Intentional Weakness) ---

resource "aws_iam_role" "mongodb_role" {
  name = "MongoDBEC2Role"

  permissions_boundary = aws_iam_policy.permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.mongodb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "mongodb_permissive_policy" {
  name = "MongoDBPermissivePolicy"
  role = aws_iam_role.mongodb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "IntentionalWeaknessEC2FullControl"
        Effect   = "Allow"
        Action   = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid      = "BackupWriteAccess"
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_backup_bucket.s3_bucket_arn,
          "${module.s3_backup_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb_profile" {
  name = "MongoDBInstanceProfile"
  role = aws_iam_role.mongodb_role.name
}