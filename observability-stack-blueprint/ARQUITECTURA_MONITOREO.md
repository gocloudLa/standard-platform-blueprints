Target Architecture

Applications:
- ECS/Fargate
- Spring Boot containers
- OpenTelemetry Java Agent

Observability stack:
- Grafana
- Grafana Mimir
- Grafana Tempo
- Grafana Loki
- OpenTelemetry Collector

Storage:
- S3

Logs:
- Grafana Loki (application logs via OTel Collector)
- CloudWatch Logs (ECS native, retained separately)

Alerting:
- Grafana Alerting -> SNS

Goals:
- Collect JVM metrics
- Collect ECS/Fargate metrics
- Collect APM traces
- Collect JDBC/Redis/external API latencies
- Collect application logs (stdout/stderr via OTel)
- Retain 6 months of history (metrics/traces)
- Retain 30 days of logs (Loki)
- Centralize everything in Grafana

```
+---------------------------------------------------+  +---------------------------------------------------+
| ECS TASK - SPRING BOOT APP 1                      |  | ECS TASK - SPRING BOOT APP 2                      |
|---------------------------------------------------|  |---------------------------------------------------|
|                                                   |  |                                                   |
|  +---------------------+  +--------------------+  |  |  +---------------------+  +--------------------+  |
|  |    App Container    |  | OTel Collector     |  |  |  |    App Container    |  | OTel Collector     |  |
|  |                     |  | (sidecar)          |  |  |  |                     |  | (sidecar)          |  |
|  | java               |  |                    |  |  |  | java               |  |                    |  |
|  |  -javaagent:otel...|  | Receives:          |  |  |  |  -javaagent:otel...|  | Receives:          |  |
|  |                     |  |  - OTLP (app)      |  |  |  |                     |  |  - OTLP (app)      |  |
|  | OTLP -> 127.0.0.1  |  |  - ECS task metrics|  |  |  | OTLP -> 127.0.0.1  |  |  - ECS task metrics|  |
|  |         :4317       |  |                    |  |  |  |         :4317       |  |                    |  |
|  +---------------------+  | Exports:           |  |  |  +---------------------+  | Exports:           |  |
|                            |  - Metrics -> Mimir|  |  |                            |  - Metrics -> Mimir|  |
|                            |  - Traces  -> Tempo|  |  |                            |  - Traces  -> Tempo|  |
|                            +--------------------+  |  |                            +--------------------+  |
+---------------------------------------------------+  +---------------------------------------------------+
                                    \                               /
                                     \                             /
                                      \                           /
                                       v                         v
                        +------------+-------------+
                        |                          |
                        v                          v
                +-------------------+      +-------------------+
                |       MIMIR       |      |       TEMPO       |
                |-------------------|      |-------------------|
                | Metrics TSDB      |      | Traces/APM        |
                | S3 backend        |      | S3 backend        |
                +-------------------+      +-------------------+
                               \                     /
                                \                   /
                                 \                 /
                                  v               v
              +---------------------------------------------------+
              |                    GRAFANA                        |
              |---------------------------------------------------|
              | Datasources:                                      |
              |  - Mimir                                          |
              |  - Tempo                                          |
              |  - CloudWatch Logs                                |
              +---------------------------------------------------+
```
================================================================================

Recommended Infrastructure

Purpose of this document (simple implementation):
- 1 replica per component (no HA)
- Everything runs on ECS/Fargate
- Service discovery via Cloud Map (e.g. `*.internal`)

Components (1 task each):
- Grafana
- Mimir
- Tempo
- OpenTelemetry Collector (sidecar per application task)

Operational notes (important):
- With 1 replica per component, if the task restarts there may be gaps without telemetry.
- The OTel Collector runs as a sidecar container within each application task. This enables the `awsecscontainermetrics` receiver to collect CPU/memory/network metrics from the task itself (requires localhost access to the ECS task metadata endpoint).
- Each application sends OTLP to 127.0.0.1:4317 (localhost within the same task), eliminating the need for service discovery for the collector.
- Mimir requires `/data` for WAL/cache. In this implementation we will NOT mount persistence (accepting the risk): on restarts/redeploys recent metrics may be lost and gaps may appear in graphs/alerts.
- Grafana can persist in `/var/lib/grafana`, but in this implementation we will NOT mount persistence (accepting the risk): on restarts/redeploys users/dashboards/config are lost (unless provisioned).

================================================================================

S3 Buckets

Create:

cliente-observability-mimir-blocks
cliente-observability-tempo-traces
cliente-observability-loki-chunks

Recommended lifecycle:
- IA after 30 days
- Glacier after 90 days (optional)

================================================================================

Loki

Documentation:
https://grafana.com/docs/loki/latest/

Purpose:
- Centralized log aggregation for all ECS application containers
- Receives logs via OTLP from the OTel Collector sidecar
- Stores log data in S3 (ephemeral local storage only for WAL/cache)
- 30-day retention (short-lived, for debugging and correlation)

Deploy strategy:
- Same as Mimir/Tempo: Alpine base image + download Loki binary at startup
- Single binary mode (all components in one process)
- S3 backend with TSDB index store
- Ephemeral /tmp/loki for WAL and cache (lost on restart, S3 persists)

Loki config:

auth_enabled: false

server:
  http_listen_port: 3100

common:
  ring:
    instance_addr: 0.0.0.0
    kvstore:
      store: inmemory
  replication_factor: 1
  path_prefix: /tmp/loki

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /tmp/loki/index
    cache_location: /tmp/loki/cache
  aws:
    region: <aws_region>
    bucketnames: <bucket_name>
    s3forcepathstyle: false

compactor:
  working_directory: /tmp/loki/compactor
  retention_enabled: true

limits_config:
  retention_period: 720h
  allow_structured_metadata: true

Notes:
- 720h = 30 days retention
- allow_structured_metadata: required for OTLP ingestion (default in Loki 3.x)
- Receives logs via OTLP HTTP endpoint at /otlp/v1/logs (port 3100)
- No Promtail or Fluent Bit needed — OTel Collector sends directly

================================================================================

OTel Collector Sidecar (updated with logs pipeline)

The sidecar now exports logs to Loki in addition to metrics and traces:

config.yaml:

receivers:
  otlp:
    protocols:
      grpc:
      http:
  awsecscontainermetrics:

processors:
  batch:

exporters:
  prometheusremotewrite:
    endpoint: http://mimir.internal:9009/api/v1/push
  otlp/traces:
    endpoint: tempo.internal:4317
    tls:
      insecure: true
  otlphttp/logs:
    endpoint: http://loki.internal:3100/otlp
    tls:
      insecure: true

service:
  pipelines:
    metrics:
      receivers: [otlp, awsecscontainermetrics]
      processors: [batch]
      exporters: [prometheusremotewrite]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/traces]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp/logs]

Notes:
- Loki requires otlphttp exporter (not gRPC otlp)
- Endpoint path is /otlp (Loki's native OTLP ingestion endpoint)
- Apps must enable OTEL_LOGS_EXPORTER=otlp to send logs via OTel

================================================================================

Grafana

Documentation:
https://grafana.com/docs/grafana/latest/

Container deploy:

docker run -d \
  --name grafana \
  -p 3000:3000 \
  grafana/grafana:latest

Persistence:
- /var/lib/grafana
- Note: in this implementation we will NOT mount persistence (accepting the risk).

Datasources to configure:
- Mimir
- Tempo
- CloudWatch

CloudWatch datasource:
- use IAM Role
- permissions:
  logs:StartQuery
  logs:GetQueryResults
  logs:DescribeLogGroups

================================================================================

Tempo

Documentation:
https://grafana.com/docs/tempo/latest/

Deploy:

docker run -d \
  --name tempo \
  -p 3200:3200 \
  -v /opt/tempo/tempo.yaml:/etc/tempo.yaml \
  grafana/tempo:latest \
  -config.file=/etc/tempo.yaml

tempo.yaml file:

server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
        http:
storage:
  trace:
    backend: s3
    s3:
      bucket: cliente-observability-tempo-traces
      region: us-east-1
compactor:
  compaction:
    block_retention: 4320h

Notes:
- Tempo receives OTLP
- Stores traces in S3
- Does not require a database
- 4320h = 6 months
- On ECS/Fargate: 1 replica is sufficient to start (no HA)

================================================================================

Mimir

Documentation:
https://grafana.com/docs/mimir/latest/

Deploy:

docker run -d \
  --name mimir \
  -p 9009:9009 \
  -v /data/mimir:/data \
  -v /opt/mimir/mimir.yaml:/etc/mimir.yaml \
  grafana/mimir:latest \
  -config.file=/etc/mimir.yaml

Requirements:
- Persistent disk mandatory
- Even with S3, it needs local WAL/cache
- Do NOT use ephemeral filesystem

Recommended mount:
- /data
- Note: in this implementation we will NOT mount persistence on `/data` (accepting the risk).

mimir.yaml file:

multitenancy_enabled: false

server:
  http_listen_port: 9009

common:
  storage:
    backend: s3

    s3:
      region: us-east-1
      bucket_name: cliente-observability-mimir-blocks
      native_aws_auth_enabled: true

blocks_storage:
  backend: s3

  s3:
    bucket_name: cliente-observability-mimir-blocks

  tsdb:
    dir: /data/tsdb

  bucket_store:
    sync_dir: /data/tsdb-sync

compactor:
  data_dir: /data/compactor

limits:
  compactor_blocks_retention_period: 4320h

Notes:
- Mimir replaces Prometheus as the primary storage
- Compatible with PromQL
- History in S3
- Configurable retention

================================================================================

OpenTelemetry Collector (Sidecar)

Documentation:
https://opentelemetry.io/docs/collector/

Deployment model:
- Runs as a sidecar container within each application ECS task
- NOT deployed as a standalone centralized service
- Each app task includes its own collector instance

Why sidecar instead of centralized:
- The `awsecscontainermetrics` receiver requires access to the ECS task metadata endpoint (localhost only), so it can only collect metrics from the task it runs in
- Lower latency for telemetry export (localhost communication)
- No single point of failure for telemetry collection
- Each task is self-contained for observability

Sidecar container config:

Image: otel/opentelemetry-collector-contrib:latest
Ports: 4317 (gRPC), 4318 (HTTP)

config.yaml file:

receivers:

  otlp:
    protocols:
      grpc:
      http:

  awsecscontainermetrics:

processors:
  batch:

exporters:

  prometheusremotewrite:
    endpoint: http://mimir.internal:9009/api/v1/push

  otlp:
    endpoint: tempo.internal:4317

    tls:
      insecure: true

service:

  pipelines:

    metrics:
      receivers:
        - otlp
        - awsecscontainermetrics

      processors:
        - batch

      exporters:
        - prometheusremotewrite

    traces:
      receivers:
        - otlp

      processors:
        - batch

      exporters:
        - otlp

Notes:
- Receives metrics and traces from the app container via localhost (127.0.0.1:4317)
- Collects ECS task-level CPU/memory/network metrics via `awsecscontainermetrics`
- Exports metrics to Mimir (via service discovery)
- Exports traces to Tempo (via service discovery)
- Each application task carries its own collector sidecar
- No centralized collector needed

================================================================================

Java Instrumentation

Documentation:
https://opentelemetry.io/docs/zero-code/java/

Download agent:

wget https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

Add to container:
- /opt/opentelemetry-javaagent.jar

Modify Java runtime:

-javaagent:/opt/opentelemetry-javaagent.jar

Recommended variables:

OTEL_SERVICE_NAME=cliente-monolith

OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317

OTEL_EXPORTER_OTLP_PROTOCOL=grpc

OTEL_METRICS_EXPORTER=otlp

OTEL_TRACES_EXPORTER=otlp

OTEL_LOGS_EXPORTER=none

Result:
- JVM metrics
- heap
- threads
- GC
- HTTP latency
- JDBC
- Redis
- Apache HTTP Client
- Spring Boot
- traces
- exceptions

No Java code changes required.

================================================================================

Grafana Datasources

Mimir:
http://mimir.internal:9009/prometheus

Tempo:
http://tempo.internal:3200

CloudWatch:
- use IAM Role
- select region

================================================================================

Recommended Dashboards

Import official Grafana dashboards:
- JVM
- Spring Boot
- ECS/Fargate
- OpenTelemetry

IDs:
4701
11159
19004

================================================================================

Alerting

Use Grafana Alerting.

Destination:
- SNS

SNS Topic:
cliente-observability-alerts

Recommended alerts:
- High CPU
- High memory
- Task restart
- Heap > 75%
- High GC pause
- High response time
- High error rate
- High JDBC latency
- Redis timeout

================================================================================

Persistence

Mimir:
- Historical metrics
- Persistence in S3
- 6 months retention

Tempo:
- Historical traces
- Persistence in S3
- 6 months retention

CloudWatch:
- Logs

================================================================================

End-to-End Flow

ECS/Fargate Application Task
    ->
OTel Java Agent (in app container)
    ->
OTel Collector Sidecar (same task, 127.0.0.1:4317)
  + awsecscontainermetrics (task-level metrics)
    ->
Mimir (metrics)
Tempo (traces)
CloudWatch (logs)
    ->
Grafana

================================================================================

Expected Final Result

- ECS/Fargate metrics
- JVM metrics
- Heap/GC/Threads
- Tomcat/Spring metrics
- Distributed tracing
- JDBC latency
- Redis latency
- External API latency
- Centralized dashboards
- Alerts
- 6 months history
- Logs/traces/metrics correlation
- No Java code changes required
