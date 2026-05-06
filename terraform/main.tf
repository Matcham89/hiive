module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

resource "aws_security_group" "cloudshell" {
  name        = "cloudshell-vpc-sg"
  description = "CloudShell VPC environment outbound only"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cloudshell-vpc-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  admin_arns         = var.admin_arns
}

resource "aws_security_group_rule" "cloudshell_to_eks" {
  type                     = "ingress"
  security_group_id        = module.eks.cluster_security_group_id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cloudshell.id
  description              = "Allow CloudShell VPC environment to reach EKS API"
}

module "monitoring" {
  source = "./modules/monitoring/cloudwatch"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  environment       = var.environment
  region            = var.aws_region

  depends_on = [module.eks]
}
