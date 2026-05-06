variable "cluster_name" {
  description = "EKS cluster name (used for subnet tagging)"
  type        = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

