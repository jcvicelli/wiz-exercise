resource "random_password" "mongodb_password" {
  length  = 20
  special = false # Simplifies connection string parsing for the exercise
}

resource "aws_secretsmanager_secret" "mongodb_auth" {
  name        = "wiz-exercise/mongodb-auth-${random_id.bucket_suffix.hex}"
  description = "MongoDB authentication credentials"

  # Allow deletion for the exercise
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongodb_auth_val" {
  secret_id = aws_secretsmanager_secret.mongodb_auth.id
  secret_string = jsonencode({
    username       = "todoapp"
    password       = random_password.mongodb_password.result
    admin_password = "Admin${random_password.mongodb_password.result}" # Simple derivative for admin
  })
}

output "mongodb_secret_arn" {
  value = aws_secretsmanager_secret.mongodb_auth.arn
}

output "mongodb_secret_name" {
  value = aws_secretsmanager_secret.mongodb_auth.name
}
