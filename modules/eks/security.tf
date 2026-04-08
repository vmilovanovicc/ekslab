# -----------------------------------------------------------------------
# Cluster Security Group
#
# Controls traffic to/from the EKS control plane.
# -----------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${var.project}-${var.environment}-eks-cluster"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-eks-cluster"
  })
}

# Allow control plane to communicate with nodes (kubelet, logs, metrics).
resource "aws_security_group_rule" "cluster_egress_to_nodes" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Control plane to node communication"
}

# Allow control plane to reach node metrics server (443).
resource "aws_security_group_rule" "cluster_egress_to_nodes_443" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Control plane to node HTTPS"
}

# -----------------------------------------------------------------------
# Node Security Group
#
# Controls traffic to/from worker nodes.
# -----------------------------------------------------------------------

resource "aws_security_group" "node" {
  name        = "${var.project}-${var.environment}-eks-node"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name                                        = "${var.project}-${var.environment}-eks-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Nodes must communicate with each other (pod-to-pod traffic).
resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
  description       = "Node to node communication"
}

# Control plane initiates connections to kubelets and webhooks on nodes.
resource "aws_security_group_rule" "node_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Control plane to node communication"
}

# Control plane needs HTTPS to reach admission webhooks on nodes.
resource "aws_security_group_rule" "node_ingress_from_cluster_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Control plane HTTPS to nodes"
}

# Nodes need outbound internet access to pull images and reach AWS APIs.
resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Node outbound internet access (image pulls, AWS APIs)"
}
