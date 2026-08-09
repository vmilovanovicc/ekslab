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
| **EKS Cluster** | Kubernetes 1.36 (default), API auth mode, public + private endpoint access, control plane logs (api/audit/authenticator/controllerManager/scheduler), Secrets envelope-encrypted with a dedicated KMS CMK |
| **Node Group** | Single managed node group ("default") in private subnets, IMDSv2 enforced, EBS encrypted with aws/ebs CMK |
| **Add-ons** | vpc-cni (IRSA + prefix delegation), kube-proxy, coredns |
| **IRSA** | OIDC provider provisioned; vpc-cni uses IRSA (node role has no CNI permissions) |
| **State Backend** | S3 with native file locking (Terraform >= 1.10, no DynamoDB required) |
| **CI/CD** | GitHub Actions with OIDC, no static AWS credentials anywhere |

**Terraform structure:**

```
bootstrap/    # One-time, locally-run config that creates the S3 state bucket
              # (own local state; can't use the bucket it creates as its own backend)
modules/
  vpc/        # VPC, subnets, IGW, NAT GW, route tables, optional flow logs, flow log IAM
  eks/        # Cluster, node group, add-ons, security groups, OIDC, IRSA, IAM roles
main.tf       # Module calls
backend.tf    # S3 remote state
budget.tf     # AWS Budget alarm (cost guardrail)
providers.tf  # Terraform and AWS provider configuration
variables.tf
outputs.tf
```

---

## Security Highlights

- **No static credentials**: GitHub Actions authenticates via OIDC. The plan and destroy jobs also check `github.actor == github.repository_owner`, and apply only runs after a successful plan, so only the repository owner can drive the pipeline.
- **Restricted API endpoint**: EKS public API locked to specific CIDRs via `allowed_cidrs`. `0.0.0.0/0` and private ranges (10.x, 172.16-31.x, 192.168.x) are rejected by input validation.
- **IMDSv2 enforced**: launch template requires token-based IMDS (hop limit 1), preventing SSRF-based credential theft from pods.
- **IRSA for vpc-cni**: node role does not carry CNI permissions; the aws-node service account assumes a scoped IRSA role instead.
- **Least-privilege node role**: nodes get `AmazonEKSWorkerNodePolicy` and `AmazonEC2ContainerRegistryPullOnly` (pull-only, not read-only).
- **Encrypted node storage**: EBS volumes are gp3, encrypted with the aws/ebs managed key, deleted on termination.
- **Secrets envelope encryption**: Kubernetes `Secret` objects are envelope-encrypted with a dedicated customer-managed KMS key (`encryption_config`), rotated automatically, not just AWS's default etcd storage encryption.
- **Cluster logging**: api, audit, authenticator, controllerManager, and scheduler logs shipped to CloudWatch with 7-day retention.
- **Custom security groups**: explicit rules for control-plane-to-node and node-to-node traffic; no catch-all ingress on the cluster or node security groups (only unrestricted egress from nodes for image pulls and AWS API access).

---

## Getting Started

### Prerequisites

The following resources must exist **before** running the pipeline. They are created once and never destroyed by Terraform:

1. **S3 state bucket**: versioning enabled, default encryption enabled, and S3 Block Public Access enabled. The state file contains plaintext infrastructure details (IAM role ARNs, OIDC thumbprints, allow-listed CIDRs) regardless of any `sensitive = true` markers in Terraform variables, so these settings are not optional.

   The [`bootstrap/`](bootstrap) directory contains a small, separate Terraform config that creates this bucket with the required settings baked in as code. It uses local state (it can't use the bucket it's creating as its own backend) and is run once per AWS account/region, by hand, before the main pipeline is used:

   ```bash
   cd bootstrap
   cp terraform.tfvars.example terraform.tfvars   # edit state_bucket_name, aws_region
   terraform init
   terraform apply
   ```

   Use the resulting bucket name as `TF_STATE_BUCKET` below. Terraform >= 1.10 is required for the main pipeline's native S3 file locking (no DynamoDB table needed).

2. **GitHub Actions OIDC IAM role**: allows the pipeline to authenticate to AWS without static credentials.
   - The AWS account must have an IAM OIDC identity provider for `token.actions.githubusercontent.com`.
   - The role's trust policy must scope to your repository, and specifically to the branch that runs this workflow, not just the repository as a whole. A common mistake is a trust condition like `repo:owner/repo:*`, which lets *any* branch, PR, or fork-triggered run in the repo assume the role. Since this role can create/destroy your entire AWS footprint, scope it as tightly as your usage allows, for example:
     ```json
     {
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
         },
         "StringLike": {
           "token.actions.githubusercontent.com:sub": "repo:owner/ekslab:ref:refs/heads/main"
         }
       }
     }
     ```
     Replace `owner/ekslab` with your actual `owner/repo`, and the `ref:refs/heads/main` value with the specific branch (or a GitHub Environment via `repo:owner/ekslab:environment:<name>`) you actually dispatch this workflow from.
   - The role needs sufficient permissions to create/destroy all ephemeral resources (VPC, EKS, IAM roles, etc.).
   - The role also needs `budgets:ViewBudget` and `budgets:ModifyBudget` (for `aws_budgets_budget` in `budget.tf`, unless `enable_budget_alarm = false`). AWS Budgets does not support resource-scoped ARNs for these actions, they must be granted with `"Resource": "*"`:
     ```json
     {
       "Effect": "Allow",
       "Action": ["budgets:ViewBudget", "budgets:ModifyBudget"],
       "Resource": "*"
     }
     ```

3. **GitHub repository secrets** set under Settings > Secrets and variables > Actions:

   | Secret | Example value |
   |---|---|
   | `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/ekslab-github-actions` |
   | `AWS_REGION` | `us-east-2` |
   | `TF_STATE_BUCKET` | `my-ekslab-tfstate` |
   | `TF_STATE_KEY` | `ekslab/terraform.tfstate` |
   | `TF_VAR_ALLOWED_CIDRS` | `["203.0.113.10/32"]` (valid JSON list, required for EKS API access) |
   | `TF_VAR_ADMIN_PRINCIPAL_ARN` | `arn:aws:iam::123456789012:user/you` (optional, grants permanent local kubectl admin) |
   | `TF_VAR_BUDGET_NOTIFICATION_EMAILS` | `["you@example.com"]` (valid JSON list, required unless `enable_budget_alarm = false`) |

   `TF_VAR_ALLOWED_CIDRS` controls which IPs can reach the EKS API endpoint. Update it whenever your public IP changes (check via `curl https://checkip.amazonaws.com`).

   `TF_VAR_ADMIN_PRINCIPAL_ARN` is optional. When set, an EKS access entry is created so that IAM principal always has cluster admin access, useful for local `kubectl` sessions independent of who ran `terraform apply`. Leave unset if not needed.

   `TF_VAR_BUDGET_NOTIFICATION_EMAILS` is where AWS Budget alerts are sent (see [Cost Considerations](#cost-considerations)). Required because `enable_budget_alarm` defaults to `true`.

4. **AWS CLI** (optional, for local runs) configured with credentials that have sufficient permissions.

**Required tool versions:**
- Terraform >= 1.10 (workflow pins 1.14.3)
- AWS provider ~> 5.0

### Connecting to the Cluster

After a successful apply, run the `kubeconfig_command` output to configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name ekslab-lab
```

Whoever ran `terraform apply` gets cluster admin automatically (`bootstrap_cluster_creator_admin_permissions`). If `TF_VAR_ADMIN_PRINCIPAL_ARN` was set, that principal also has permanent admin access regardless of who applied.

### Outputs

| Output | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs (one per AZ) |
| `private_subnet_ids` | Private subnet IDs (one per AZ), where EKS nodes run |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS cluster API server endpoint |
| `oidc_provider_arn` | ARN of the EKS OIDC provider, used for IRSA |
| `kubeconfig_command` | Ready-to-run `aws eks update-kubeconfig` command |

---

## CI/CD Workflow

The workflow (`.github/workflows/deploy-eks-lab.yml`) is triggered manually via `workflow_dispatch` with an `action` input (`apply` or `destroy`).

**Apply** runs as two sequential jobs, gated to the repository owner:

1. **Plan**: inits, checks formatting, validates, plans, and uploads the plan artifact (1-day retention). Only runs when `action = apply` and the actor is the repository owner.
2. **Apply**: downloads the plan artifact and applies it with `-auto-approve`. Runs after `plan` succeeds, so it is implicitly skipped whenever `plan` is skipped or fails.

**Destroy** runs as a single job. It requires `action = destroy`, the actor to be the repository owner, and `confirm_destroy` typed as exactly `destroy`.

A concurrency group (`terraform-eks-lab`) serializes runs so plan, apply, and destroy never execute against the state at the same time.

Terraform provider binaries are cached between runs keyed on `.terraform.lock.hcl`.

---

## Cost Considerations

This lab is designed to minimize cost. Resources only incur charges while running.

| Resource | Approximate cost (subject to change) | Notes |
|---|---|---|
| EKS control plane | ~$0.10/hour | Main fixed cost |
| NAT Gateway | ~$0.045/hour + data | Single NAT by default |
| EC2 node (`t3.medium`) | ~$0.047/hour | 1 node by default |
| EBS (20 GB gp3) | ~$0.002/hour | Encrypted with aws/ebs (free) |
| KMS key (Secrets encryption) | ~$1/month | Prorated to lab uptime; used for `encryption_config` |
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

### Guardrails Against Forgotten Costs

- **AWS Budget alarm** on by default (`enable_budget_alarm = true`), that emails `TF_VAR_BUDGET_NOTIFICATION_EMAILS` when actual spend crosses 80% of `budget_limit_usd` (default $20/month) or forecasted spend is on track to exceed 100%. Near-zero cost to run.
- **Lab TTL Check workflow** (`.github/workflows/lab-ttl-check.yml`): runs daily, checks the age of any EKS cluster tagged `Project = ekslab`, and opens (or updates) a GitHub issue if it has been running longer than `TTL_WARNING_HOURS` (default 8h). It only warns, it does not destroy anything automatically, you still need to trigger `destroy` yourself.
