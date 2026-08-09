variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name used for resource naming and tagging"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the node group"
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "List of CIDRs permitted to reach the EKS public API endpoint. Must not include 0.0.0.0/0."
  type        = list(string)
  sensitive   = true
}

variable "admin_principal_arn" {
  description = "IAM principal ARN (user or role) granted permanent cluster admin access for local kubectl use. Set to null to skip."
  type        = string
  default     = null
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 3
}

variable "node_volume_size" {
  description = "Root EBS volume size (GB) for EKS nodes"
  type        = number
  default     = 20
}

variable "node_capacity_type" {
  description = "EKS node group capacity type. SPOT cuts EC2 cost ~60-70% with interruption risk, a non-issue for a disposable lab; use ON_DEMAND if interruptions are unacceptable."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be either \"ON_DEMAND\" or \"SPOT\"."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period (in days) for the EKS cluster log group"
  type        = number
  default     = 7
}

variable "vpc_cni_addon_version" {
  description = "Version of the vpc-cni EKS add-on to install. Null resolves to the latest version compatible with cluster_version at apply time."
  type        = string
  default     = null
}

variable "kube_proxy_addon_version" {
  description = "Version of the kube-proxy EKS add-on to install. Null resolves to the latest version compatible with cluster_version at apply time."
  type        = string
  default     = null
}

variable "coredns_addon_version" {
  description = "Version of the coredns EKS add-on to install. Null resolves to the latest version compatible with cluster_version at apply time."
  type        = string
  default     = null
}
