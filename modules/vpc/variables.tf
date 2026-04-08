variable "project" {
  description = "Project name, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. lab, dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet tags required by the AWS load balancer controller"
  type        = string
}

variable "enable_nat_gateway_per_az" {
  description = "Deploy one NAT Gateway per AZ. Default: false (single NAT Gateway, cost-optimized)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs. Default: false (cost-optimized)."
  type        = bool
  default     = false
}
