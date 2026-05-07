# EKS Terraform Module

Deploys a private EKS cluster on AWS with a containerized nginx application and CloudWatch observability. 

All infrastructure is managed as code via Terraform modules.

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

The two Terraform roots are intentionally separate. The infra root (`terraform/`) uses only the AWS provider and can run from any machine. The Kubernetes root (`terraform/k8s/`) uses the Kubernetes provider and must run from inside the AWS network because the EKS API endpoint is private.

---

## Prerequisites

### Phase 1 — local machine

| Tool | Minimum version |
|---|---|
| Terraform | 1.5.0 |
| AWS CLI | 2.x configured with your credentials |

### Phase 2 — AWS CloudShell (VPC environment)

No local tooling required. The deploy script installs Terraform automatically. 

CloudShell must be configured as a **VPC environment** so it can resolve and reach the private EKS API endpoint — instructions in step 4 below.

AWS credentials must have permissions to create: VPC, EKS, IAM roles, CloudWatch resources, EC2 security groups.

---

## Step-by-step deployment

### 1. Bootstrap (one-time, clickops)

Two resources are created manually before Terraform runs — both exist outside the state to avoid chicken-and-egg dependencies:

**S3 state bucket**
```bash
aws s3api create-bucket \
  --bucket terraform-state-637423429740-us-east-1-an \
  --region us-east-1
```

**IAM accounts** — created via the AWS console:
- `terraform-github-actions` — assumed by GitHub Actions via OIDC to deploy infrastructure
- `dev-account` — used by developers for CLI access and AWS console. Credentials stored in 1Password.

### 2. Deploy Phase 1 — AWS infrastructure

Trigger the Terraform GitHub Action manually:

1. GitHub → **Actions** → **Terraform**
2. Click **Run workflow**

This provisions:
- VPC with public/private subnets and NAT Gateway
- EKS Auto Mode cluster (private endpoint)
- IAM roles (CloudWatch IRSA, dev-account)
- A `cloudshell-vpc-sg` security group for the CloudShell VPC environment
- An ingress rule on the EKS cluster security group allowing 443 from `cloudshell-vpc-sg`
- CloudWatch Container Insights, alarms, and dashboard

Takes ~10–15 minutes.

### 3. Create the CloudShell VPC environment

Phase 2 runs from CloudShell **inside the VPC** so it can reach the private EKS endpoint and pull from GitHub via NAT Gateway.
Authenticate using the dev-account credentials from 1Password.
1. AWS Console → top-right toolbar → **CloudShell**
2. **Actions → Create environment**
3. Configure:
   - **Name**: `hiive-vpc`
   - **VPC**: value from `terraform output vpc_id`
   - **Subnet**: value from `terraform output private_subnet_id` (must be private — public subnets won't have internet from CloudShell)
   - **Security group**: value from `terraform output cloudshell_security_group_id`
4. Click **Create** (~1 minute)

### 4. Deploy Phase 2 — Kubernetes application (CloudShell VPC environment)

In the CloudShell VPC environment paste this single command. It clones the repo, installs Terraform if needed, then runs `init`, `apply`, and configures kubectl:

```bash
git clone https://github.com/Matcham89/hiive.git && bash hiive/terraform/k8s/deploy.sh
```

Deploys the application namespace, deployment, and service (~1–2 minutes).

### 5. Verify the application

Still in CloudShell, check the pods and port-forward to preview:

```bash
kubectl get pods -n hello-world
kubectl get svc  -n hello-world

# Port-forward to preview the service from CloudShell
kubectl port-forward -n hello-world svc/hello-world 8080:80
```

In CloudShell, click **Actions → Preview running application** (or use the web preview button on port 8080) to open the nginx welcome page in your browser.

### 6. View observability

Navigate to **CloudWatch → Dashboards → hiive-eks-overview** in the AWS Console, or get the direct URL from your local machine:

Control-plane logs: **CloudWatch → Log groups → `/aws/eks/hiive/cluster`**

---

## Making changes

All infrastructure changes go through code — open a pull request, get it merged, and the GitHub Action will apply it. Do not make manual changes to resources managed by Terraform.

---

## Destroying infrastructure

1. GitHub → **Actions** → **Terraform Destroy**
2. Click **Run workflow**
3. In the confirmation field type `destroy` and click **Run workflow**

The workflow requires the word `destroy` to be typed explicitly before it will proceed. It runs `terraform destroy -auto-approve` against `prod.tfvars`.

> The S3 state bucket and `terraform-github-actions` role are not managed by Terraform and will not be destroyed by this workflow — they must be removed manually if needed.

---

## Design decisions

### EKS Auto Mode

EKS Auto Mode lets AWS manage the full node lifecycle — provisioning, patching, and bin-packing via an integrated Karpenter — without requiring a separate node group or launch template configuration. This removes a significant chunk of operational overhead. The trade-off is less low-level control over node configuration, which is an acceptable exchange for most workloads that don't have exotic hardware requirements.

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

## Future improvements

| Item | Reason |
|---|---|
| DynamoDB state lock table | Prevents state corruption if two Terraform runs execute concurrently |
| Scoped IAM permissions for `terraform-github-actions` | `AdministratorAccess` is broader than necessary; least-privilege reduces blast radius of a compromised token |
| KMS key for state bucket | Gives an audit trail of who accessed or decrypted state, and allows key rotation |

---

## Inputs

| Name | Description | Default       |
|---|---|---------------|
| `aws_region` | AWS region | `us-east-1`   |
| `environment` | Environment name | `prod`        |
| `cluster_name` | EKS cluster name | `hiive`       |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `kubernetes_version` | Kubernetes version | `1.34`        |

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
