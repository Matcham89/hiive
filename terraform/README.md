# EKS Terraform Module

Deploys a private EKS cluster on AWS with a containerised hello-world application and CloudWatch observability. All infrastructure is managed as code via Terraform modules.

---

**Key properties:**

| Property | Detail |
|---|---|
| Cluster API endpoint | Private only — not reachable from the internet |
| Node networking | Private subnets; outbound via NAT Gateway |
| Application exposure | `ClusterIP` only — no public load balancer |
| Image pulls | Outbound via NAT Gateway to public ECR |
| Observability | CloudWatch Container Insights (metrics + logs) |

---

## Module Structure

```
terraform/
├── main.tf                          # Root — wires modules together
├── variables.tf
├── outputs.tf
├── versions.tf
├── providers.tf
├── backend.tf
└── modules/
    ├── vpc/                         # VPC, subnets, NAT Gateway, IGW
    ├── eks/                         # EKS Auto Mode cluster, control-plane logs
    ├── app/                         # Kubernetes Deployment + ClusterIP Service
    └── monitoring/
        └── cloudwatch/              # Container Insights addon, alarms, dashboard
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Terraform | 1.5.0 |
| AWS CLI | 2.x |
| kubectl | 1.29+ |

AWS credentials must have permissions to create: VPC, EKS, IAM roles, CloudWatch resources.

---

## Step-by-step deployment

### 1. Clone the repository

```bash
git clone <repo-url>
cd terraform
```

### 2. Configure state backend

The S3 bucket referenced in `backend.tf` must exist before you run `terraform init`. Create it once:

```bash
aws s3api create-bucket \
  --bucket terraform-state-<your-account-id>-us-east-1 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-<your-account-id>-us-east-1 \
  --versioning-configuration Status=Enabled
```

Update `backend.tf` with your bucket name, or switch to local state for a quick test:

```hcl
# backend.tf — local state (remove for production)
terraform {
  backend "local" {}
}
```

### 3. Initialise Terraform

```bash
terraform init
```

### 4. Apply Phase 1 — infrastructure

The `kubernetes` Terraform provider needs to connect to the EKS API to deploy the app. Since the cluster doesn't exist yet, run a targeted apply first to create the VPC and cluster:

```bash
terraform apply -target=module.vpc -target=module.eks
```

This takes approximately 10–15 minutes.

### 5. Establish cluster connectivity

Once the cluster is up, configure kubectl:

```bash
$(terraform output -raw configure_kubectl)
# expands to: aws eks update-kubeconfig --name hiive --region us-east-1
```

**Connectivity note:** because the API endpoint is private, you must run kubectl (and the next Terraform apply) from within the AWS network. Options:

- **AWS CloudShell** — launch from the AWS Console; it runs inside AWS and can reach private EKS endpoints.
- **EC2 bastion** — a small instance in a private subnet, accessed via SSM Session Manager.
- **AWS Client VPN / Direct Connect** — if your network is already connected.

For local development, you can temporarily enable the public endpoint by setting `cluster_endpoint_public_access = true` in `modules/eks/main.tf`, then revert it after.

### 6. Apply Phase 2 — application and monitoring

From a machine with connectivity to the cluster:

```bash
terraform apply
```

This deploys the hello-world app and installs the CloudWatch Container Insights addon (~3–5 minutes).

### 7. Verify the application

```bash
kubectl get pods -n hello-world
kubectl get svc  -n hello-world

# Forward the service port locally
kubectl port-forward -n hello-world svc/hello-world 8080:80
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

### 8. View observability

```bash
terraform output cloudwatch_dashboard_url
```

Or navigate to **CloudWatch → Dashboards → hiive-eks-overview** in the AWS Console.

Control-plane logs are in: **CloudWatch → Log groups → `/aws/eks/hiive/cluster`**

---

## Design decisions

### EKS Auto Mode

EKS Auto Mode (launched at re:Invent 2024) lets AWS manage the full node lifecycle — provisioning, patching, and bin-packing via an integrated Karpenter — without requiring a separate node group or launch template configuration. This removes a significant chunk of operational overhead. The trade-off is less low-level control over node configuration, which is an acceptable exchange for most workloads that don't have exotic hardware requirements.

### Private cluster with NAT Gateway for outbound

The Kubernetes API endpoint is private (`cluster_endpoint_public_access = false`), so the control plane is not reachable from the internet. Worker nodes sit in private subnets with no public IPs. A single NAT Gateway in the public subnet handles all outbound traffic, including pulling images from public ECR and Docker Hub, without exposing any inbound path. A single NAT Gateway is intentional here to keep costs low for this demo; a production deployment should run one NAT Gateway per Availability Zone to survive an AZ failure.

---

## Inputs

| Name | Description | Default |
|---|---|---|
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment name | `dev` |
| `cluster_name` | EKS cluster name | `hiive` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `kubernetes_version` | Kubernetes version | `1.33` |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Private API endpoint (sensitive) |
| `configure_kubectl` | Shell command to configure kubectl |
| `vpc_id` | VPC ID |
| `cloudwatch_dashboard_url` | URL to the CloudWatch dashboard |
