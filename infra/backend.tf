terraform {
  backend "s3" {
    bucket         = "terrafrom-state-ghost"
    key            = "terraform-state.tfstate"
    encrypt        = true
    region         = "us-east-1"
  }
}
