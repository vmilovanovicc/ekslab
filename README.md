# EKS Lab

A secure, cost-efficient AWS EKS environment built with Terraform and deployed via GitHub Actions. Designed as an ephemeral lab, created and destroyed per session, with a focus on security best practices and clean infrastructure design.

---

## Purpose

This lab provisions a managed Kubernetes cluster on AWS EKS for:

- Learning and hands-on experimentation with Kubernetes on AWS
- Running test workloads in a realistic cloud environment

It is not a production system, but it is built with a focus on security: no hardcoded credentials, least-privilege IAM, encrypted storage, restricted API access, and keyless CI/CD via GitHub OIDC.

---

## Key Components

| Component | Details |
|---|---|
| **VPC** | 2 AZs, public + private subnets, single NAT Gateway (cost-optimized) |
| **EKS Cluster** | Kubernetes 1.35 (default), API auth mode, control plane logs (api/audit/authenticator) |
| **Node Group** | Managed, in private subnets, IMDSv2 enforced, EBS encrypted with aws/ebs CMK |
| **Add-ons** | vpc-cni (IRSA + prefix delegation), kube-proxy, coredns |
| **IRSA** | OIDC provider provisioned; vpc-cni uses IRSA (node role has no CNI permissions) |
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

## Security Highlights

- **No static credentials** — GitHub Actions authenticates via OIDC; only the repository owner can trigger the workflow
- **Restricted API endpoint** — EKS public API locked to specific CIDRs via `allowed_cidrs`; `0.0.0.0/0` and private ranges are rejected by input validation
- **IMDSv2 enforced** — launch template requires token-based IMDS (hop limit 1), preventing SSRF-based credential theft from pods
- **IRSA for vpc-cni** — node role does not carry CNI permissions; the aws-node service account assumes a scoped IRSA role
- **Encrypted node storage** — EBS volumes are gp3, encrypted with the aws/ebs managed key, deleted on termination
- **Cluster logging** — api, audit, and authenticator logs shipped to CloudWatch with 7-day retention
- **Custom security groups** — explicit rules for control-plane-to-node and node-to-node traffic; no catch-all ingress

---

## Getting Started

### Prerequisites

The following resources must exist **before** running the pipeline. They are created once and never destroyed by Terraform:

1. **S3 state bucket** versioning enabled, native file locking support (Terraform >= 1.10)

2. **GitHub Actions OIDC IAM role** allows the pipeline to authenticate to AWS without static credentials
   - Trust policy must allow `token.actions.githubusercontent.com` for your repository
   - Must have sufficient permissions to create/destroy all ephemeral resources (VPC, EKS, IAM roles, etc.)

3. **GitHub repository secrets** set under Settings > Secrets and variables > Actions:

   | Secret | Example value |
   |---|---|
   | `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/ekslab-github-actions` |
   | `AWS_REGION` | `us-east-2` |
   | `TF_STATE_BUCKET` | `my-ekslab-tfstate` |
   | `TF_STATE_KEY` | `ekslab/terraform.tfstate` |
   | `TF_VAR_ALLOWED_CIDRS` | `["203.0.113.10/32"]` — valid JSON list, required for EKS API access |
   | `TF_VAR_ADMIN_PRINCIPAL_ARN` | `arn:aws:iam::123456789012:user/you` — optional, grants permanent local kubectl admin |

   `TF_VAR_ALLOWED_CIDRS` controls which IPs can reach the EKS API endpoint. Update it whenever your public IP changes (check via `curl https://checkip.amazonaws.com`).

   `TF_VAR_ADMIN_PRINCIPAL_ARN` is optional. When set, an EKS access entry is created so that IAM principal always has cluster admin access, useful for local `kubectl` sessions independent of who ran `terraform apply`. Leave unset if not needed.

4. **AWS CLI** (optional, for local runs) configured with credentials that have sufficient permissions

**Required tool versions:**
- Terraform >= 1.10 (workflow pins 1.14.3 TBU)
- AWS provider >= 5.x

### Connecting to the Cluster

After a successful apply, run the `kubeconfig_command` output to configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name ekslab-lab
```

---

## CI/CD Workflow

The workflow (`.github/workflows/deploy-eks-lab.yml`) is triggered manually via `workflow_dispatch`. Only the repository owner can run it.

**Apply** runs as two sequential jobs:

1. **Plan** inits, validates, formats-check, plans, uploads the plan artifact (1-day retention)
2. **Apply** downloads the artifact and applies the saved plan

**Destroy** runs as a single job and requires typing `destroy` in the confirmation input to proceed.

A concurrency group (`terraform-eks-lab`) prevents parallel runs from corrupting state.

---

## Cost Considerations

This lab is designed to minimise cost. Resources only incur charges while running. 

| Resource | Approximate cost (subject to change) | Notes |
|---|---|---|
| EKS control plane | ~$0.10/hour | Main fixed cost |
| NAT Gateway | ~$0.045/hour + data | Single NAT by default |
| EC2 node (`t3.medium`) | ~$0.047/hour | 1 node by default |
| EBS (20 GB gp3) | ~$0.002/hour | Encrypted with aws/ebs (free) |
| CloudWatch logs | Minimal | 7-day retention |
| VPC Flow Logs | Off by default | Enable with `enable_flow_logs = true` |
| CloudTrail | Not included | Excluded to avoid S3 storage accumulation |

**Estimated total: ~$0.20-0.25/hour** while running. Destroy after each session.

Cost-saving defaults that can be changed via variables:

| Variable | Default | Notes |
|---|---|---|
| `enable_nat_gateway_per_az` | `false` | Single NAT Gateway; set to `true` for per-AZ resilience |
| `enable_flow_logs` | `false` | No flow log storage costs |
| `node_instance_type` | `t3.medium` | Configurable |
| `node_desired_size` | `1` | Configurable (min 1, max 3) |
