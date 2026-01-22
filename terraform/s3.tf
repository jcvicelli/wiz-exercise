resource "random_id" "bucket_suffix" {
  byte_length = 4
}

module "s3_backup_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.0"

  bucket = "wiz-exercise-mongodb-backups-${random_id.bucket_suffix.hex}"

  # Intentional Misconfiguration: Public Access Enabled
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy        = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource  = [
          "arn:aws:s3:::wiz-exercise-mongodb-backups-${random_id.bucket_suffix.hex}",
          "arn:aws:s3:::wiz-exercise-mongodb-backups-${random_id.bucket_suffix.hex}/*"
        ]
      }
    ]
  })

  tags = {
    IntentionalWeakness = "PublicBucket"
    DataClassification  = "Public"
  }
}

output "backup_bucket_name" {
  description = "Name of the S3 bucket for backups"
  value       = module.s3_backup_bucket.s3_bucket_id
}
