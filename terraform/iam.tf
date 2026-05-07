module "iam" {
  source = "./modules/iam"

  environment       = var.environment
  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider

  depends_on = [module.eks]
}
