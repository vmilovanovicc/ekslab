variable "aws_region" {
  description = "AWS region to create the state bucket in"
  type        = string
}

variable "state_bucket_name" {
  description = "Globally-unique name for the Terraform state bucket (must match TF_STATE_BUCKET used by the pipeline)"
  type        = string
}

variable "project" {
  description = "Project name used for tagging"
  type        = string
  default     = "ekslab"
}

variable "environment" {
  description = "Environment name used for tagging"
  type        = string
  default     = "lab"
}
