terraform {
  backend "s3" {
    bucket         = "wiz-exercise-terraform-state-jcvicelli" # Hardcoded unique name for this exercise
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
