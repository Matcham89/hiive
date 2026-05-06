output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.eks.dashboard_name}"
}

output "cloudwatch_role_arn" {
  value = aws_iam_role.cloudwatch_observability.arn
}
