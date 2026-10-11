variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "two-tier-eks"
}

variable "cluster_version" {
  description = "Check `aws eks describe-cluster-versions` for versions in standard support"
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "github_owner" {
  type = string
}

variable "app_repo" {
  description = "Repository holding the application code (allowed to push images and deploy)"
  type        = string
  default     = "two-tier-app"
}

variable "admin_principal_arns" {
  description = "IAM users/roles (e.g. your own IAM user) that get kubectl admin. Do not include the infra CI role; it is the cluster creator and already has admin."
  type        = list(string)
  default     = []
}
