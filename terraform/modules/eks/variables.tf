variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "admin_arns" {
  description = "IAM principal ARNs to grant EKS cluster-admin access (e.g. CloudShell role, CI role)"
  type        = list(string)
  default     = []
}

