# Copy these into the APP repo once. Names are fixed, so they survive destroy/recreate.
output "app_repo_settings" {
  value = {
    "secret   AWS_ROLE_ARN" = aws_iam_role.app_deploy.arn
    "variable AWS_REGION"   = var.region
    "variable EKS_CLUSTER"  = module.eks.cluster_name
    "variable ECR_BACKEND"  = aws_ecr_repository.app["backend"].name
    "variable ECR_FRONTEND" = aws_ecr_repository.app["frontend"].name
  }
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
