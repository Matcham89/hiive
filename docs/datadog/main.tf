# NOTE: Assumes 'submit_order' is available as an operation_name in Datadog APM.
# This depends on Spandex span names matching the GraphQL operation names defined in the Elixir application.
# Verify in Datadog APM > Traces before applying.

locals {
  common_tags = ["env:production", "team:sre"]
}

resource "datadog_synthetics_test" "critical_path" {
  name      = "Synthetic: Critical Transaction Path"
  type      = "api"
  subtype   = "http"
  status    = "live"
  message   = "Notify @pagerduty"
  locations = ["aws:eu-central-1"]
  tags      = concat(local.common_tags, ["severity:critical"])

  request_definition {
    method    = "POST"
    url       = "https://api.hiive.com/graphql"
    body_type = "graphql"
    body = jsonencode({
      # Simulates a real customer completing a transaction every 15 minutes and alerts if anything goes wrong.
      query = "mutation SubmitOrder($input: SubmitOrderInput!) { submitOrder(input: $input) { id status } }"
    })
  }

  request_headers = {
    "Content-Type" = "application/json"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "body"
    operator = "doesNotContain"
    target   = "\"errors\":"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = 3000
  }

  options_list {
    tick_every = 900
    retry {
      count    = 2
      interval = 300
    }
    monitor_options {
      renotify_interval = 120
    }
  }
}

resource "datadog_monitor" "graphql_mutation_error_rate" {
  name               = "[P1] GraphQL SubmitOrder Error Rate"
  type               = "query alert"
  message            = "Monitor triggered. Notify: @hipchat-channel"
  escalation_message = "Escalation message @pagerduty"
  # Tracks what percentage of SubmitOrder requests are failing and alertis if it goes above 2%
  query = "avg(last_5m):sum:trace.graphql.server.errors{env:production,operation_name:submit_order}.as_rate() / sum:trace.graphql.server.hits{env:production,operation_name:submit_order}.as_rate() * 100 > 2"

  monitor_thresholds {
    warning  = 1
    critical = 2
  }

  include_tags = true

  tags = concat(local.common_tags, ["impact:api", "severity:critical"])
}

resource "datadog_monitor" "postgres_deadlocks" {
  name               = "[P1] PostgreSQL Deadlocks Detected"
  type               = "query alert"
  message            = "Monitor triggered. Notify: @hipchat-channel"
  escalation_message = "Escalation message @pagerduty"
  # Alerts immediately if any database deadlocks are detected, because on this platform even one is unacceptable.
  query = "sum(last_5m):postgresql.deadlocks{env:production} > 0"

  monitor_thresholds {
    critical = 0
  }

  include_tags   = true
  notify_no_data = false
  tags           = concat(local.common_tags, ["impact:api", "severity:critical"])
}
