resource "aws_ecr_repository" "app" {
  name = "wiz-exercise-todo-app"
  # allows latest tag, but it's not secure
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_ecr_lifecycle_policy" "app_policy" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
