# EKS Lab

A secure, cost-efficient AWS EKS environment built with Terraform and deployed via GitHub Actions. Designed as an ephemeral lab, created and destroyed per session, with a focus on security best practices and clean infrastructure design.

---

## Purpose

This lab provisions a managed Kubernetes cluster on AWS EKS for:

- Learning and hands-on experimentation with Kubernetes on AWS
- Running test workloads in a realistic cloud environment

It is not a production system, but it is built with focus on security: no hardcoded credentials, least-privilege IAM, encrypted storage, restricted API access, and keyless CI/CD via GitHub OIDC.

---

## Key Components

| Component | Details |
|---|---|
| **VPC** | 2 AZs, public + private subnets, single NAT Gateway (cost-optimized) |
| **State Backend** | S3 with native file locking (Terraform >= 1.10, no DynamoDB required) |
| **CI/CD** | GitHub Actions with OIDC, no static AWS credentials anywhere |

**Terraform structure:**

```
modules/
  vpc/        # VPC, subnets, IGW, NAT GW, route tables, optional flow logs
  eks/        # Cluster, node group, add-ons, security groups, OIDC, IRSA
main.tf       # Module calls
backend.tf    # S3 remote state
variables.tf
outputs.tf
```

---

## Getting Started

### Prerequisites

The following resources must exist **before** running the pipeline. They are created once and never destroyed by Terraform:

1. **S3 state bucket** - with versioning enabled and native file locking support

2. **GitHub Actions OIDC IAM role** - allows the pipeline to authenticate to AWS without static credentials
   - Trust policy must allow `token.actions.githubusercontent.com` for your repository
   - Must have sufficient permissions to create/destroy all ephemeral resources (VPC, EKS, IAM roles, etc.)

3. **GitHub repository secrets** - set under Settings > Secrets and variables > Actions:

   | Secret | Example value |
   |---|---|
   | `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/ekslab-github-actions` |
   | `AWS_REGION` | `us-east-2` |
   | `TF_STATE_BUCKET` | `my-ekslab-tfstate` |
   | `TF_STATE_KEY` | `ekslab/terraform.tfstate` |
   | `TF_VAR_ALLOWED_CIDRS` | `["203.0.113.10/32"]` - valid JSON list, required for EKS |

   `TF_VAR_ALLOWED_CIDRS` controls which IPs can reach the EKS API endpoint. Update it whenever your IP changes.

4. **AWS CLI** (optional, for local runs) - configured with credentials that have sufficient permissions

**Required tool versions:**
- Terraform >= 1.10
- AWS provider >= 5.x

### Cost Considerations

This lab is designed to minimise cost. Resources only incur charges while running.

| Resource | Approximate cost | Notes |
|---|---|---|
| EKS control plane | ~$0.10/hour | Main fixed cost |
| NAT Gateway | ~$0.045/hour + data | Single NAT by default |
| EC2 node (`t3.medium`) | ~$0.047/hour | 1 node by default |
| EBS (20 GB default) | ~$0.002/hour | Encrypted with aws/ebs (free) |
| CloudWatch logs | Minimal | 7-day retention |
| VPC Flow Logs | Off by default | Enable with `enable_flow_logs = true` |
| CloudTrail | Not included | Excluded to avoid S3 storage accumulation |

**Estimated total: ~$0.20-0.25/hour** while running. Destroy after each session.

Cost-saving defaults that can be changed via variables:
- `enable_nat_gateway_per_az = false` - single NAT Gateway
- `enable_flow_logs = false` - no flow log storage costs
- Instance type and node count are configurable
