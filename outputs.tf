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
  description = "Private subnet IDs (one per AZ),EKS nodes are placed here"
  value       = module.vpc.private_subnet_ids
}

