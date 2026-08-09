module "vpc" {
  source = "./modules/vpc"

  project                   = var.project
  environment               = var.environment
  vpc_cidr                  = var.vpc_cidr
  cluster_name              = var.cluster_name
  enable_nat_gateway_per_az = var.enable_nat_gateway_per_az
  enable_flow_logs          = var.enable_flow_logs
  az_count                  = var.az_count
  log_retention_days        = var.log_retention_days
}

module "eks" {
  source = "./modules/eks"

  project         = var.project
  environment     = var.environment
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  allowed_cidrs       = var.allowed_cidrs
  admin_principal_arn = var.admin_principal_arn

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_volume_size   = var.node_volume_size

  log_retention_days       = var.log_retention_days
  vpc_cni_addon_version    = var.vpc_cni_addon_version
  kube_proxy_addon_version = var.kube_proxy_addon_version
  coredns_addon_version    = var.coredns_addon_version
}
