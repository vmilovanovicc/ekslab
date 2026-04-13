# Discover available AZs in the current region and use the first 2.
# Filters to only "available" state to exclude opted-out or restricted zones.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  az_count           = length(local.availability_zones)

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}"
  })
}

# -----------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------

# Public subnets,  used for load balancers and NAT Gateways only.
# Nodes are never placed here. map_public_ip_on_launch is intentionally off.
resource "aws_subnet" "public" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name                     = "${var.project}-${var.environment}-public-${count.index + 1}"
      "kubernetes.io/role/elb" = "1"
    },
    var.cluster_name != null ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )
}

# Private subnets, EKS nodes run here.
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name                              = "${var.project}-${var.environment}-private-${count.index + 1}"
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.cluster_name != null ? { "kubernetes.io/cluster/${var.cluster_name}" = "shared" } : {}
  )
}

# -----------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}"
  })
}

# -----------------------------------------------------------------------
# NAT Gateways
#
# Default: single NAT Gateway in the first public subnet (cost-optimized).
# Optional: one NAT Gateway per AZ for resilience (enable_nat_gateway_per_az).
# -----------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway_per_az ? local.az_count : 1
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-nat-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway_per_az ? local.az_count : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-public"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ. When using a single NAT Gateway, all
# private route tables route through index 0. When per-AZ, each routes
# through its own NAT Gateway.
resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.enable_nat_gateway_per_az ? aws_nat_gateway.main[count.index].id : aws_nat_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------
# VPC Flow Logs 
# -----------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.project}-${var.environment}/flow-logs"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_flow_log" "main" {
  count           = var.enable_flow_logs ? 1 : 0
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn

  tags = local.common_tags
}
