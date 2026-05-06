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
├── main.tf                          # Infra root — VPC, EKS, monitoring
├── variables.tf
├── outputs.tf
├── versions.tf
├── providers.tf
├── backend.tf                       # State key: hiive/terraform.tfstate
├── k8s/                             # Kubernetes root — run from inside VPC
│   ├── main.tf
│   ├── providers.tf                 # Reads cluster config from AWS EKS API
│   ├── variables.tf
│   ├── versions.tf
│   ├── outputs.tf
│   └── backend.tf                   # State key: hiive/k8s.tfstate
└── modules/
    ├── vpc/                         # VPC, subnets, NAT Gateway, IGW
    ├── eks/                         # EKS Auto Mode cluster, control-plane logs
    ├── app/                         # Kubernetes Deployment + ClusterIP Service
    └── monitoring/
        └── cloudwatch/              # Container Insights addon, alarms, dashboard
```

The two Terraform roots are intentionally separate. The infra root (`terraform/`) uses only the AWS provider and can run from any machine. The Kubernetes root (`terraform/k8s/`) uses the Kubernetes provider and must run from inside the AWS network because the EKS API endpoint is private.

---

## Prerequisites

### Phase 1 — local machine

| Tool | Minimum version |
|---|---|
| Terraform | 1.5.0 |
| AWS CLI | 2.x configured with your credentials |

### Phase 2 — AWS CloudShell (VPC environment)

No local tooling required. The deploy script installs Terraform automatically. CloudShell must be configured as a **VPC environment** so it can resolve and reach the private EKS API endpoint — instructions in step 4 below.

AWS credentials must have permissions to create: VPC, EKS, IAM roles, CloudWatch resources, EC2 security groups.

---

## Step-by-step deployment

### 1. Clone the repository (local machine)

```bash
git clone https://github.com/Matcham89/hiive.git
```

### 2. Configure state backend

The S3 bucket referenced in both `backend.tf` files must exist before you run `terraform init`. Create it once from your local machine:

```bash
aws s3api create-bucket \
  --bucket terraform-state-<your-account-id>-us-east-1 \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-<your-account-id>-us-east-1 \
  --versioning-configuration Status=Enabled
```

Update the `bucket` field in both `terraform/backend.tf` and `terraform/k8s/backend.tf` with your bucket name.

### 3. Deploy Phase 1 — AWS infrastructure (local machine)

The `terraform/` root uses only the AWS provider and has no dependency on the EKS API. Run this from your local machine.

```bash
cd terraform
terraform init
terraform apply
```

This provisions:
- VPC with public/private subnets and NAT Gateway
- EKS Auto Mode cluster (private endpoint)
- A `cloudshell-vpc-sg` security group for the CloudShell VPC environment
- An ingress rule on the EKS cluster security group allowing 443 from `cloudshell-vpc-sg`
- CloudWatch Container Insights, alarms, and dashboard

Takes ~10–15 minutes. Note the outputs at the end — you'll need them for step 4:

```bash
terraform output vpc_id
terraform output private_subnet_id
terraform output cloudshell_security_group_id
```

### 4. Create the CloudShell VPC environment

Phase 2 runs from CloudShell **inside the VPC** so it can reach the private EKS endpoint and pull from GitHub via NAT Gateway.

1. AWS Console → top-right toolbar → **CloudShell**
2. **Actions → Create environment**
3. Configure:
   - **Name**: `hiive-vpc`
   - **VPC**: value from `terraform output vpc_id`
   - **Subnet**: value from `terraform output private_subnet_id` (must be private — public subnets won't have internet from CloudShell)
   - **Security group**: value from `terraform output cloudshell_security_group_id`
4. Click **Create** (~1 minute)

### 5. Deploy Phase 2 — Kubernetes application (CloudShell VPC environment)

In the CloudShell VPC environment created above, paste this single command. It clones the repo, installs Terraform if needed, then runs `init`, `apply`, and configures kubectl:

```bash
git clone https://github.com/Matcham89/hiive.git && bash hiive/terraform/k8s/deploy.sh
```

Deploys the hello-world namespace, deployment, and service (~1–2 minutes).

### 6. Verify the application

Still in CloudShell, check the pods and port-forward to preview:

```bash
kubectl get pods -n hello-world
kubectl get svc  -n hello-world

# Port-forward to preview the service from CloudShell
kubectl port-forward -n hello-world svc/hello-world 8080:80
```

In CloudShell, click **Actions → Preview running application** (or use the web preview button on port 8080) to open the nginx welcome page in your browser.

### 7. View observability

Navigate to **CloudWatch → Dashboards → hiive-eks-overview** in the AWS Console, or get the direct URL from your local machine:

```bash
# From your local machine in terraform/
terraform output cloudwatch_dashboard_url
```

Control-plane logs: **CloudWatch → Log groups → `/aws/eks/hiive/cluster`**

---

## Design decisions

### EKS Auto Mode

EKS Auto Mode (launched at re:Invent 2024) lets AWS manage the full node lifecycle — provisioning, patching, and bin-packing via an integrated Karpenter — without requiring a separate node group or launch template configuration. This removes a significant chunk of operational overhead. The trade-off is less low-level control over node configuration, which is an acceptable exchange for most workloads that don't have exotic hardware requirements.

### Private cluster with NAT Gateway for outbound

The Kubernetes API endpoint is private (`cluster_endpoint_public_access = false`), so the control plane is not reachable from the internet. Worker nodes sit in private subnets with no public IPs. A single NAT Gateway in the public subnet handles all outbound traffic, including pulling images from public ECR and Docker Hub, without exposing any inbound path. A single NAT Gateway is intentional here to keep costs low for this demo; a production deployment should run one NAT Gateway per Availability Zone to survive an AZ failure.

### CloudShell VPC environment for in-VPC tooling

Because the EKS API endpoint is private, deployment tooling (kubectl, the Kubernetes Terraform provider) must run from inside the VPC. Rather than provisioning a long-running EC2 bastion, this stack uses an **AWS CloudShell VPC environment** placed in a private subnet — same network reachability, but no instance to keep patched and no costs when idle.

The `cloudshell-vpc-sg` security group has no inbound rules and unrestricted egress, and an explicit `aws_security_group_rule` opens port 443 on the EKS cluster security group only from this SG. Combined with the existing `admin_arns` access entry, this gives CloudShell exactly the permissions it needs to deploy Phase 2 and nothing more.

---

## Follow-up questions

### How would you expose this application to the internet without a public EKS endpoint?

The EKS API endpoint stays private — that constraint is about who can reach the Kubernetes control plane, not about whether the application can serve traffic. Exposing the application uses a separate data-plane path:

1. **Install the AWS Load Balancer Controller** into the cluster (via Helm or an EKS addon). This controller watches for `Ingress` resources and provisions Application Load Balancers in AWS automatically.

2. **Change the Service type to `NodePort`** (or leave it `ClusterIP` and set `alb.ingress.kubernetes.io/target-type: ip`).

3. **Add an Ingress resource** with the ALB annotations:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: hello-world
     namespace: hello-world
     annotations:
       kubernetes.io/ingress.class: alb
       alb.ingress.kubernetes.io/scheme: internet-facing
       alb.ingress.kubernetes.io/target-type: ip
   spec:
     rules:
       - http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: hello-world
                   port:
                     number: 80
   ```

The ALB controller provisions an ALB in the **public subnets** (already tagged `kubernetes.io/role/elb = 1` in the VPC module). Traffic flows: `internet → ALB (public subnet) → pod IP (private subnet)`. The EKS API server is never involved in this data path, so the private endpoint constraint is fully preserved.

In Terraform, this means adding an IRSA role for the LBC, a `helm_release` for the controller, and a `kubernetes_ingress_v1` resource — none of which require the cluster to have a public endpoint.

---

### Security decisions and tradeoffs

**Private API endpoint (`endpoint_public_access = false`)**
The Kubernetes control plane accepts no connections from the internet. An attacker who obtains a valid `kubeconfig` still cannot reach the API server without being inside the AWS network (VPC, VPN, or Direct Connect). Tradeoff: local `kubectl` and Terraform runs require a bastion, VPN, or CloudShell, which adds operational friction.

**Worker nodes in private subnets, no public IPs**
Nodes have no inbound internet path. Even if a container is compromised, the blast radius is limited to what can be reached from inside the VPC. Outbound traffic (image pulls, CloudWatch, AWS API calls) leaves via NAT Gateway, which provides a single auditable egress point.

**Single NAT Gateway**
A single NAT Gateway keeps the demo cost low (~$35/month vs ~$105/month for three). In production, one NAT Gateway per Availability Zone is required — if the AZ hosting the NAT GW fails, nodes in other AZs lose all outbound connectivity. This tradeoff is explicitly accepted here for a non-production environment.

**IRSA for CloudWatch (IAM Roles for Service Accounts)**
The CloudWatch agent pod assumes an IAM role via the EKS OIDC provider rather than using node-level IAM policies or static credentials. This means the `CloudWatchAgentServerPolicy` is scoped only to that specific service account — other pods on the same node get no CloudWatch permissions. The role trust policy is locked to `system:serviceaccount:amazon-cloudwatch:cloudwatch-agent`.

**Pinned container image (`nginx:1.27-alpine`)**
Using a pinned, minimal base image (Alpine) over `nginx:latest` reduces the attack surface and ensures deterministic deploys. `latest` can pull a different binary on every apply, making rollbacks ambiguous and CVE tracking unreliable.

**Resource requests and limits on the container**
Explicit CPU/memory limits (`100m` / `128Mi`) prevent a misbehaving pod from starving other workloads on the same node. Requests (`50m` / `64Mi`) allow the scheduler to make placement decisions accurately. Omitting limits is a common misconfiguration that enables noisy-neighbour problems and uncapped resource consumption.

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
| `vpc_id` | VPC ID — used when creating the CloudShell VPC environment |
| `private_subnet_id` | Private subnet ID — used for the CloudShell VPC environment |
| `cloudshell_security_group_id` | Security group for the CloudShell VPC environment (allowed to reach EKS API on 443) |
| `cloudwatch_dashboard_url` | URL to the CloudWatch dashboard |
