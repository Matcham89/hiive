variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image" {
  description = "Container image to deploy"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:alpine"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 2
}
