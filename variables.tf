# -----------------------------------------------------------------------
# Global
# -----------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "ekslab"
}

variable "environment" {
  description = "Environment name used for resource naming and tagging"
  type        = string
  default     = "lab"
}

# -----------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "enable_nat_gateway_per_az" {
  description = "Deploy one NAT Gateway per AZ. Default: false (single NAT Gateway, cost-optimized)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch. Default: false (cost-optimized)."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ekslab-lab"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "allowed_cidrs" {
  description = "List of CIDRs permitted to reach the EKS public API endpoint. Must not include 0.0.0.0/0."
  type        = list(string)
  sensitive   = true

  validation {
    condition     = alltrue([for cidr in var.allowed_cidrs : can(cidrnetmask(cidr))])
    error_message = "All entries in allowed_cidrs must be valid CIDR blocks."
  }

  validation {
    condition     = !contains(var.allowed_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not allowed - the EKS API endpoint must not be publicly open."
  }

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidrs : !anytrue([
        cidrcontains("10.0.0.0/8", cidr),
        cidrcontains("172.16.0.0/12", cidr),
        cidrcontains("192.168.0.0/16", cidr),
      ])
    ])
    error_message = "Private IP ranges (10.x, 172.16-31.x, 192.168.x) are not allowed. Use your public IP from https://checkip.amazonaws.com."
  }
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
