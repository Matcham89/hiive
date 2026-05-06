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

### Phase 2 — AWS CloudShell

No local tooling required. CloudShell comes with Terraform, AWS CLI, and kubectl pre-installed and runs inside the AWS network with your console credentials automatically available.

AWS credentials must have permissions to create: VPC, EKS, IAM roles, CloudWatch resources.

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

This provisions the VPC, EKS cluster, and CloudWatch observability (~10–15 minutes).

### 4. Deploy Phase 2 — Kubernetes application (AWS CloudShell)

The EKS API endpoint is private — the Kubernetes Terraform provider cannot reach it from the internet. **AWS CloudShell** runs inside the AWS network and can reach private EKS endpoints without any VPN or bastion setup.

**Open CloudShell:** AWS Console → top-right toolbar → CloudShell icon

In the CloudShell terminal:

```bash
git clone https://github.com/Matcham89/hiive.git
cd hiive/terraform/k8s
terraform init
terraform apply
```

This deploys the hello-world namespace, deployment, and service (~1–2 minutes).

### 5. Verify the application

Still in CloudShell, configure kubectl and check the pods:

```bash
aws eks update-kubeconfig --name hiive --region us-east-1

kubectl get pods -n hello-world
kubectl get svc  -n hello-world

# Port-forward to preview the service from CloudShell
kubectl port-forward -n hello-world svc/hello-world 8080:80
```

In CloudShell, click **Actions → Preview running application** (or use the web preview button on port 8080) to open the nginx welcome page in your browser.

### 6. View observability

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
| `vpc_id` | VPC ID |
| `cloudwatch_dashboard_url` | URL to the CloudWatch dashboard |
