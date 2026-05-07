aws_region         = "us-east-1"
environment        = "production"
cluster_name       = "hiive"
vpc_cidr           = "10.0.0.0/16"
kubernetes_version = "1.34"
admin_arns = [
  "arn:aws:iam::637423429740:user/dev_account",
  "arn:aws:iam::637423429740:role/terraform-github-actions",
]
