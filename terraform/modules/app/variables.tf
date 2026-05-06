variable "environment" {
  type = string
}

variable "image" {
  description = "Container image to deploy"
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 2
}
