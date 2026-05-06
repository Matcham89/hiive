module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "app" {
  source = "./modules/app"

  cluster_name = var.cluster_name
  environment  = var.environment

  depends_on = [module.eks]
}

module "monitoring" {
  source = "./modules/monitoring/cloudwatch"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  environment       = var.environment

  depends_on = [module.eks]
}
