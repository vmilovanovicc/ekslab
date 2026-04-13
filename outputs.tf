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
