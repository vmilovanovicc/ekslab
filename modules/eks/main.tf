data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------
# Secrets Encryption (KMS)
# -----------------------------------------------------------------------

resource "aws_kms_key" "eks_secrets" {
  description             = "Envelope encryption key for ${var.cluster_name} Kubernetes Secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.project}-${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# -----------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = local.common_tags
}

# -----------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.allowed_cidrs
  }

  access_config {
    authentication_mode = "API"
    # Whoever runs terraform apply gets cluster admin automatically.
    # Covers both GitHub Actions deployments and local manual runs.
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy.cluster_kms,
    aws_cloudwatch_log_group.cluster,
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------
# EKS Access Entry - persistent local admin
#
# Optional: grants a fixed IAM principal (local IAM user or role)
# permanent cluster admin access, independent of who ran terraform apply.
# Set admin_principal_arn = null to skip.
# -----------------------------------------------------------------------

resource "aws_eks_access_entry" "admin" {
  count         = var.admin_principal_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"

  tags = local.common_tags
}

resource "aws_eks_access_policy_association" "admin" {
  count         = var.admin_principal_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# -----------------------------------------------------------------------
# Node Group Launch Template
# -----------------------------------------------------------------------

resource "aws_launch_template" "node" {
  name_prefix = "${var.project}-${var.environment}-node-"

  # IMDSv2 enforced - prevents SSRF-based credential theft from pods.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = data.aws_kms_key.ebs.arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project}-${var.environment}-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------
# Managed Node Group
# -----------------------------------------------------------------------

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------
# Add-ons
# -----------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.vpc_cni.arn

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })

  depends_on = [
    aws_iam_role_policy_attachment.vpc_cni_policy,
  ]

  tags = local.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.default]

  tags = local.common_tags
}
