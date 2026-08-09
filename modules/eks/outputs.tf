output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider, used for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig for this cluster"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}

output "secrets_kms_key_arn" {
  description = "ARN of the KMS key used for Kubernetes Secrets envelope encryption"
  value       = aws_kms_key.eks_secrets.arn
}
