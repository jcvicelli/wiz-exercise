# --- CloudTrail (Detective Control) ---

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "wiz-exercise-cloudtrail-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "wiz-exercise-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_policy]
}

# --- AWS Config (Detective Control) ---

resource "aws_s3_bucket" "config_logs" {
  bucket        = "wiz-exercise-config-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "config_policy" {
  bucket = aws_s3_bucket.config_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config_logs.arn
      },
      {
        Sid    = "AWSConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "wiz-exercise-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  name           = "wiz-exercise-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_logs.id
  depends_on     = [aws_config_configuration_recorder.main]
}

# Config Rule: S3 Public Read Prohibited
resource "aws_config_config_rule" "s3_public_read" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config Rule: Security Groups attached to ENI
resource "aws_config_config_rule" "sg_attached" {
  name = "ec2-security-group-attached-to-eni"

  source {
    owner             = "AWS"
    source_identifier = "EC2_SECURITY_GROUP_ATTACHED_TO_ENI"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config Rule: Restricted SSH
resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config Rule: EC2 Managed by SSM
resource "aws_config_config_rule" "ec2_ssm_managed" {
  name = "ec2-instance-managed-by-systems-manager"

  source {
    owner             = "AWS"
    source_identifier = "EC2_INSTANCE_MANAGED_BY_SSM"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Config Rule: EKS Logging Enabled
resource "aws_config_config_rule" "eks_logging" {
  name = "eks-cluster-logging-enabled"

  source {
    owner             = "AWS"
    source_identifier = "EKS_CLUSTER_LOGGING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# --- IAM Permission Boundary (Preventative Control) ---

resource "aws_iam_policy" "permission_boundary" {
  name        = "MongoDBPermissionBoundary"
  description = "Permission boundary for MongoDB instance to limit max permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSpecificActions"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "ssm:UpdateInstanceInformation",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMChanges"
        Effect = "Deny"
        Action = [
          "iam:*",
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "organizations:*"
        ]
        Resource = "*"
      }
    ]
  })
}
