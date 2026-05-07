output "dev_account_user_arn" {
  value = aws_iam_user.dev_account.arn
}

output "cloudwatch_observability_role_arn" {
  value = aws_iam_role.cloudwatch_observability.arn
}
