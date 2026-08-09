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

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period (in days), applied to VPC Flow Logs and the EKS cluster log group"
  type        = number
  default     = 7
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
        can(regex("^10\\.", cidr)),
        can(regex("^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", cidr)),
        can(regex("^192\\.168\\.", cidr)),
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

variable "node_volume_size" {
  description = "Root EBS volume size (GB) for EKS nodes"
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------
# Cost Guard
# -----------------------------------------------------------------------

variable "enable_budget_alarm" {
  description = "Create an AWS Budget with email alerts as a safety net for forgotten/runaway resources. Requires budget_notification_emails."
  type        = bool
  default     = true
}

variable "budget_limit_usd" {
  description = "Monthly budget threshold (USD) that triggers alert notifications."
  type        = number
  default     = 20
}

variable "budget_notification_emails" {
  description = "Email addresses notified when the budget threshold is exceeded. Required when enable_budget_alarm is true."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.enable_budget_alarm || length(var.budget_notification_emails) > 0
    error_message = "budget_notification_emails must contain at least one email when enable_budget_alarm is true."
  }
}
