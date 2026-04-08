module "vpc" {
  source = "./modules/vpc"

  project                   = var.project
  environment               = var.environment
  vpc_cidr                  = var.vpc_cidr
  cluster_name              = var.cluster_name
  enable_nat_gateway_per_az = var.enable_nat_gateway_per_az
  enable_flow_logs          = var.enable_flow_logs
}

# module "eks" {
#   source = "./modules/eks"
#   ...
# }
