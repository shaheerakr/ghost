provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      ## these tags are used for all resources
      owner   = "Ghost Team"
      project = "Ghost"
    }
  }
}
