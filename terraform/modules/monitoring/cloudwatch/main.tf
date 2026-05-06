# IRSA role for the CloudWatch Container Insights addon
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

# CloudWatch Container Insights — ships node and pod metrics + logs to CloudWatch
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = var.cluster_name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = aws_iam_role.cloudwatch_observability.arn

  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  alarm_description   = "EKS node CPU utilization > 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  alarm_description   = "EKS node memory utilization > 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_restarts" {
  alarm_name          = "${var.cluster_name}-pod-restarts"
  alarm_description   = "Pod restart count exceeds threshold — check for crashlooping containers"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "pod_number_of_container_restarts"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "eks" {
  dashboard_name = "${var.cluster_name}-eks-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Node CPU Utilization (%)"
          region  = var.region
          metrics = [["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Node Memory Utilization (%)"
          region  = var.region
          metrics = [["ContainerInsights", "node_memory_utilization", "ClusterName", var.cluster_name]]
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Running Containers"
          region  = var.region
          metrics = [["ContainerInsights", "pod_number_of_running_containers", "ClusterName", var.cluster_name]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Pod Restarts"
          region  = var.region
          metrics = [["ContainerInsights", "pod_number_of_container_restarts", "ClusterName", var.cluster_name]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 12
        width  = 24
        height = 3
        properties = {
          title = "Cluster Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.node_cpu_high.arn,
            aws_cloudwatch_metric_alarm.node_memory_high.arn,
            aws_cloudwatch_metric_alarm.pod_restarts.arn,
          ]
        }
      }
    ]
  })
}
