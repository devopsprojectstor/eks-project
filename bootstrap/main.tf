# Run ONCE, locally, with your own AWS credentials.
# Creates what the infra pipeline needs before it can run itself:
#   - S3 bucket for Terraform remote state
#   - GitHub OIDC provider
#   - IAM role the infra repo's GitHub Actions assume
# Keep this local state file safe (or just re-import if lost); it changes rarely.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "github_owner" {
  type = string
}

variable "infra_repo" {
  description = "Name of the infra repository"
  type        = string
  default     = "two-tier-infra"
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has token.actions.githubusercontent.com"
  type        = bool
  default     = true
}

data "aws_caller_identity" "current" {}

# ---------------- Remote state bucket ----------------
resource "aws_s3_bucket" "tfstate" {
  bucket = "${data.aws_caller_identity.current.account_id}-two-tier-tfstate"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------- GitHub OIDC provider ----------------
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ---------------- Role for the infra pipeline ----------------
resource "aws_iam_role" "infra_ci" {
  name = "two-tier-infra-ci"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_owner}/${var.infra_repo}:pull_request",     # plan on PRs
            "repo:${var.github_owner}/${var.infra_repo}:environment:infra" # apply/destroy
          ]
        }
      }
    }]
  })
}

# Broad on purpose so the learning project works end to end.
# Tighten to only VPC/EKS/EC2/ECR/IAM/S3 actions once everything runs.
resource "aws_iam_role_policy_attachment" "infra_ci_admin" {
  role       = aws_iam_role.infra_ci.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "infra_ci_role_arn" {
  description = "GitHub secret AWS_ROLE_ARN in the infra repo"
  value       = aws_iam_role.infra_ci.arn
}
