# Infrastructure Repository

OpenTofu infrastructure code for provisioning AWS resources across three accounts.

## Account Structure

| Account         | Purpose                                      |
|-----------------|----------------------------------------------|
| SharedServices  | State backend (S3/DynamoDB), Route 53 DNS    |
| Test            | Test EKS cluster and supporting services     |
| Production      | Production EKS cluster and supporting services|

## Prerequisites

- Docker Desktop (or Docker Engine on Linux)
- VS Code with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- AWS IAM Identity Center access to all three accounts
- AWS CLI configured with SSO profiles: `shared-services`, `test`, `prod`

## Getting Started

1. Clone this repo
2. Open in VS Code → "Reopen in Container"
3. Log in to AWS: `aws sso login --profile shared-services`
4. Copy `terraform.tfvars.example` to `terraform.tfvars` in each environment and fill in values

## Structure
modules/                 # Reusable OpenTofu modules
├── vpc/                 # VPC, subnets, NAT gateway
├── eks/                 # EKS cluster, OIDC provider
├── karpenter/           # Karpenter controller + NodePool
└── cluster-addons/      # Ingress, cert-manager, external-dns, Argo CD
environments/            # Per-account configurations
├── shared-services/     # S3 state backend, DynamoDB, Route 53
├── test/                # Test cluster infrastructure
└── prod/                # Production cluster infrastructure

## Applying Infrastructure

Always apply in this order:

1. `environments/shared-services/` (state backend, DNS)
2. `environments/test/` (test cluster)
3. `environments/prod/` (production cluster)

```bash
cd environments/test
tofu init
tofu plan
tofu apply
```

## Without Dev Container (not recommended)

If you prefer to work without the dev container, install locally:
- OpenTofu 1.11.x
- AWS CLI v2
- kubectl
- Helm
- tflint
- tfsec