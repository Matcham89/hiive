variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
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
