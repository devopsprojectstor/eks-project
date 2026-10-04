output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_backend_repo" {
  description = "Use as GitHub variable ECR_BACKEND"
  value       = aws_ecr_repository.app["backend"].name
}

output "ecr_frontend_repo" {
  description = "Use as GitHub variable ECR_FRONTEND"
  value       = aws_ecr_repository.app["frontend"].name
}

output "github_actions_role_arn" {
  description = "Use as GitHub secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
