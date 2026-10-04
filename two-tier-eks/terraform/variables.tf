variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name (also used as a prefix for other resources)"
  type        = string
  default     = "two-tier-eks"
}

variable "cluster_version" {
  description = "Kubernetes version. Check `aws eks describe-cluster-versions` for versions in standard support."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "github_owner" {
  description = "GitHub user or org that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set false if your AWS account already has the token.actions.githubusercontent.com OIDC provider"
  type        = bool
  default     = true
}
