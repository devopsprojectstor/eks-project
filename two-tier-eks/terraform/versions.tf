terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Local state is fine for a learning project.
  # For a team, move state to S3 (create the bucket first):
  # backend "s3" {
  #   bucket       = "your-tf-state-bucket"
  #   key          = "two-tier-eks/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.cluster_name
      ManagedBy = "terraform"
    }
  }
}
