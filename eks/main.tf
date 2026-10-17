data "aws_availability_zones" "available" {
  state = "available"
}

# Created once by bootstrap/
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  human_admins = {
    for arn in var.admin_principal_arns : replace(arn, "/[^a-zA-Z0-9]/", "-") => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

# ---------------- Network ----------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  azs  = local.azs

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

# ---------------- EKS ----------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  # The infra CI role runs apply, so it becomes cluster admin.
  # It installs Argo CD and lets the destroy workflow clean up first.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_enabled_log_types = []

  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }

  # Only humans get kubectl access here. The app pipeline no longer needs any:
  # Argo CD, running inside the cluster, does the deploying.
  access_entries = local.human_admins
}

# ---------------- ECR ----------------
resource "aws_ecr_repository" "app" {
  for_each = toset(["backend", "frontend"])

  name                 = "${var.cluster_name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------- Role for the APP repo's pipeline ----------------
# With Argo CD, this role only pushes images. It has no access to the cluster.
resource "aws_iam_role" "app_deploy" {
  name = "${var.cluster_name}-app-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_owner}/${var.app_repo}:ref:refs/heads/main",
            "repo:${var.github_owner}@*/${var.app_repo}@*:ref:refs/heads/main"
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_deploy" {
  name = "ecr-push"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeImages"
        ]
        Resource = [for r in aws_ecr_repository.app : r.arn]
      }
    ]
  })
}
