variable "environment" {
  type = string
}

variable "image" {
  description = "Container image to deploy"
  type        = string
  default     = "nginx:latest"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 2
}
