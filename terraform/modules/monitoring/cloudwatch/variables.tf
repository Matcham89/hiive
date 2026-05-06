variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider" {
  description = "OIDC provider URL without https:// prefix"
  type        = string
}

variable "environment" {
  type = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
