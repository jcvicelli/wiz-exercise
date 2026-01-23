terraform {
  backend "s3" {
    bucket  = "wiz-exercise-terraform-state-jcvicelli" # Hardcoded unique name for this exercise
    key     = "terraform-bootstrap.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}
