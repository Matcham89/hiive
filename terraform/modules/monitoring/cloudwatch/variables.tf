variable "cluster_name" {
  type = string
}

variable "cloudwatch_observability_role_arn" {
  description = "IAM role ARN for the CloudWatch observability IRSA"
  type        = string
}

variable "environment" {
  type = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
