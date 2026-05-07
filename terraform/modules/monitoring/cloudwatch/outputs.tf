output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.eks.dashboard_name}"
}

output "cloudwatch_role_arn" {
  value = var.cloudwatch_observability_role_arn
}
