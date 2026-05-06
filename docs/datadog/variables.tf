variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment (used in monitor tags and queries)"
  type        = string
  default     = "production"
}

variable "pagerduty_handle" {
  description = "PagerDuty handle for critical alert routing"
  type        = string
  default     = "@pagerduty"
}

variable "api_url" {
  description = "Base URL for synthetic API tests"
  type        = string
  default     = "https://api.hiive.com/graphql"
}
