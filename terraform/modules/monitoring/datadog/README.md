Key Points
GraphQL - Payload over HTTP status / Traces
Postgres RDS - Datadog DBM
Low frequency High Transactional

Use RED and focus on Business Impact
Rate
Error
Duration

Requirements
- Datadog Agent
- Datadog APM
- Datadog Log Management
- Datadog DBM
- Datadog RUM
- Spandex
- SpandexDatadog

Every GraphQL operation is captured as a trace, with spans propagated through to Ecto queries. End-to-end visibility from the GraphQL request through to the PostgreSQL query that executes it. Trace sampling is set to 100% for critical mutations.

Elixir's Logger is configured with a JSON formatter, outputting logs with trace_id and span_id fields injected by Spandex. Logs are shipped via the Datadog Agent.

Appropriate Log Levels:
- error: System-breaking issues.
- warn: Recoverable errors or unexpected behaviors (e.g., API retries).

Infrastructure Metrics

- Node-level metrics (CPU, memory, disk pressure)

- Pod and container metrics via the kubelet integration

- Kubernetes state metrics (replica counts, deployment health) via kube-state-metrics

Database Monitoring

Datadog Database Monitoring on the RDS PostgreSQL instance. Query-level execution plans, wait event analysis, and slow query identification.

Real User Monitoring (RUM)

Capture front-end errors, page load performance, and session replays. For a high-value transaction platform, being able to replay the client-side session of a failed transaction is operationally valuable.
