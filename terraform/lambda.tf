data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/backup.py"
  output_path = "${path.module}/lambda/backup.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "MongoDBBackupLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "MongoDBBackupLambdaPolicy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ec2:us-west-2:${data.aws_caller_identity.current.account_id}:instance/${module.ec2_mongodb.id}",
          "arn:aws:ssm:us-west-2:*:document/AWS-RunShellScript"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.mongodb_auth.arn
      }
    ]
  })
}

resource "aws_lambda_function" "backup_lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "wiz-exercise-mongodb-backup"
  role          = aws_iam_role.lambda_role.arn
  handler       = "backup.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BACKUP_BUCKET = module.s3_backup_bucket.s3_bucket_id
      SECRET_NAME   = aws_secretsmanager_secret.mongodb_auth.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "mongodb-daily-backup"
  description         = "Trigger MongoDB backup daily at 2 AM UTC"
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_backup.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.backup_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_backup.arn
}
