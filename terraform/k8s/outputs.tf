output "namespace" {
  description = "Kubernetes namespace"
  value       = module.app.namespace
}

output "deployment_name" {
  description = "Kubernetes deployment name"
  value       = module.app.deployment_name
}

output "service_name" {
  description = "Kubernetes service name"
  value       = module.app.service_name
}
