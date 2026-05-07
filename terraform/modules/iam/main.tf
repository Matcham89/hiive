data "aws_caller_identity" "current" {}

# IAM User: dev-account
resource "aws_iam_user" "dev_account" {
  name = "dev-account"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_user_policy_attachment" "dev_account_admin" {
  user       = aws_iam_user.dev_account.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Role: terraform-github-actions
resource "aws_iam_role" "terraform_github_actions" {
  name = "terraform-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:Matcham89/hiive:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_github_actions_admin" {
  role       = aws_iam_role.terraform_github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IRSA Role: CloudWatch Container Insights
resource "aws_iam_role" "cloudwatch_observability" {
  name = "${var.cluster_name}-cloudwatch-observability"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.cloudwatch_observability.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
