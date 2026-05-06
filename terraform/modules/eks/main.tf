module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Private-only API endpoint — the cluster control plane is not reachable from the internet.
  # Nodes reach the API via an internal AWS PrivateLink endpoint.
  endpoint_public_access  = false
  endpoint_private_access = true

  # EKS Auto Mode — AWS manages node provisioning, scaling, and lifecycle.
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Ship all control-plane log streams to CloudWatch Logs
  enabled_log_types = [
    "audit",
    "api",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
