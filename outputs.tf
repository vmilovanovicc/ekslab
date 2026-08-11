# -----------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ), EKS nodes are placed here"
  value       = module.vpc.private_subnet_ids
}

# -----------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl"
  value       = module.eks.kubeconfig_command
}

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used for Kubernetes Secrets envelope encryption"
  value       = module.eks.secrets_kms_key_arn
}

# -----------------------------------------------------------------------
# Cost Guard
# -----------------------------------------------------------------------

output "budget_name" {
  description = "Name of the AWS Budget monitoring this lab's spend, if enabled"
  value       = var.enable_budget_alarm ? aws_budgets_budget.cost_guard[0].name : null
}
