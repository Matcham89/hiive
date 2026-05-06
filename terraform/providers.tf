provider "aws" {
  region = var.aws_region
}

# The kubernetes provider is configured after the EKS cluster is created.
# On first apply, target only the vpc and eks modules:
#   terraform apply -target=module.vpc -target=module.eks
# Then run a full apply to deploy the app and monitoring.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}
