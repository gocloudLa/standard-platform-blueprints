# Observability Stack Blueprint

## Overview

Production-ready observability stack on ECS/Fargate using open-source components (Grafana, Mimir, Tempo) with OpenTelemetry instrumentation. Collects metrics and distributed traces from any application using a sidecar pattern — no code changes required for supported languages.

### Architecture

```
App Container (OTel agent/SDK, localhost)
  → ADOT Sidecar (same task, collects app + ECS container metrics)
    → Mimir (metrics, S3 backend, 6-month retention)
    → Tempo (traces, S3 backend, 6-month retention)
      → Grafana (visualization)
```

Each ECS task includes an ADOT Collector sidecar that receives telemetry via localhost and also scrapes ECS task-level metrics (CPU, memory, network). No centralized collector needed.

---

## Stack Services

| Service | Role | Image | Ports |
|---------|------|-------|-------|
| **Grafana** | Dashboards & alerting | `grafana/grafana:13.0.1` | 3000 |
| **Mimir** | Metrics storage (Prometheus-compatible, S3) | Alpine + [Mimir binary](https://github.com/grafana/mimir) | 9009 |
| **Tempo** | Traces storage (OTLP, S3) | Alpine + [Tempo binary](https://github.com/grafana/tempo) | 3200, 4317, 4318 |
| **ADOT Collector** | Sidecar per task | `public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3` | 4317, 4318 |

---

## Demo Applications

Sample apps included to validate the full telemetry pipeline. Each one demonstrates zero-code instrumentation for its language.

| Demo | Language | Instrumentation Method | URL |
|------|----------|----------------------|-----|
| `demo-java` | Java 21 (Zipkin) | OTel Java Agent (`-javaagent`) | `https://demo-java.lab.democorp.cloud` |
| `demo-nodejs` | Node.js 22 | `@opentelemetry/auto-instrumentations-node` | `https://demo-nodejs.lab.democorp.cloud` |
| `demo-php` | PHP 8.3 | OTel PHP extension (C) + Composer SDK | `https://demo-php.lab.democorp.cloud` |

---

## Quick Start (Post-Deploy)

After the stack is deployed via `tofu apply`, follow these steps to configure Grafana:

### 1. Access Grafana

Open `https://grafana.lab.democorp.cloud`

Default credentials: `admin` / `admin`

### 2. Generate a Service Account Token

This token is used by the sync scripts to manage datasources and dashboards via API.

1. Go to **Administration** → **Service Accounts**
2. Click **Add service account**
3. Name: `automation`, Role: **Editor**
4. Click the created account → **Add token**
5. Copy the `glsa_...` token

### 3. Create Datasources

Update the `GRAFANA_TOKEN` value in `resources/create-datasources.sh` with your token, then run:

```bash
bash resources/create-datasources.sh
```

This creates/updates three datasources: Prometheus (Mimir), Tempo, and CloudWatch.

### 4. Sync Dashboards

Update the `GRAFANA_TOKEN` value in `resources/sync-dashboards.sh` (same token), then run:

```bash
bash resources/sync-dashboards.sh
```

This pushes all JSON dashboards from `resources/dashboards/` to Grafana. Run it again after any dashboard edit to sync changes.

### 5. Generate Test Traffic

```bash
curl https://demo-java.lab.democorp.cloud/actuator/health
curl https://demo-nodejs.lab.democorp.cloud/work
curl https://demo-php.lab.democorp.cloud/
```

### 6. Verify in Grafana

- **Metrics**: Explore → Prometheus → `{service_name=~"dmc-lab-obs-.*"}`
- **Traces**: Explore → Tempo → Search by service name

---

## Instrumentation Guide

How each demo is instrumented — use these patterns to add observability to a real application.

### Java — OpenTelemetry Java Agent

**Zero-code**. The OTel Java Agent auto-instruments JVM metrics, HTTP, JDBC, Redis, gRPC, and more.

**How it works in the demo:**

1. Download the agent JAR at container startup
2. Pass `-javaagent:/path/to/opentelemetry-javaagent.jar` to the `java` command
3. Configure via environment variables

**To replicate in your app:**

```dockerfile
# In your Dockerfile or entrypoint
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar /opt/otel-agent.jar

CMD ["java", "-javaagent:/opt/otel-agent.jar", "-jar", "/app/my-app.jar"]
```

**Required environment variables:**

```
OTEL_SERVICE_NAME=my-service-name
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_METRICS_EXPORTER=otlp
OTEL_TRACES_EXPORTER=otlp
OTEL_LOGS_EXPORTER=none
```

**What you get automatically:** JVM heap/GC/threads metrics, HTTP server latency histograms, database call traces, distributed trace propagation across services.

---

### Node.js — Auto-Instrumentation SDK

**Near zero-code**. Requires a small `tracing.js` bootstrap file loaded before the app.

**How it works in the demo:**

1. Install OTel packages via npm
2. Create a `tracing.js` that initializes the SDK
3. Run with `node -r ./tracing.js app.js`

**To replicate in your app:**

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-metrics-otlp-grpc \
  @opentelemetry/exporter-trace-otlp-grpc
```

Create `tracing.js`:
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const sdk = new NodeSDK({ instrumentations: [getNodeAutoInstrumentations()] });
sdk.start();
```

Run: `node -r ./tracing.js app.js`

**Required environment variables:** same as Java (change `OTEL_SERVICE_NAME`).

**What you get automatically:** HTTP request/response traces (Express, Fastify, Koa), DNS lookups, database queries, outbound HTTP calls.

---

### PHP — OTel Extension + Composer SDK

**Zero-code** once the extension is installed. Uses `http/protobuf` protocol (no gRPC extension needed).

**How it works in the demo:**

1. Install the prebuilt `php83-pecl-opentelemetry` extension from Alpine edge/testing
2. Install SDK packages via Composer
3. Set `OTEL_PHP_AUTOLOAD_ENABLED=true` — the extension hooks into all function calls automatically

**To replicate in your app:**

```bash
# Alpine-based image
echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
apk add php83-pecl-opentelemetry@testing php83-openssl php83-curl composer

# In your project
composer require open-telemetry/sdk open-telemetry/exporter-otlp php-http/guzzle7-adapter
```

**Required environment variables:**

```
OTEL_PHP_AUTOLOAD_ENABLED=true
OTEL_SERVICE_NAME=my-service-name
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=none
```

> **Important**: Use port `4318` (HTTP) not `4317` (gRPC). The PHP gRPC extension requires >2GB RAM to compile — use `http/protobuf` instead.

**What you get automatically:** Function call traces, HTTP request spans, framework-level instrumentation (Laravel, Symfony, Slim).

---

## ADOT Sidecar Configuration

Every instrumented task needs this sidecar container. The config goes in the `AOT_CONFIG_CONTENT` environment variable:

```yaml
receivers:
  otlp:
    protocols:
      grpc:    # port 4317 — Java, Node.js
      http:    # port 4318 — PHP
  awsecscontainermetrics:  # ECS task CPU/memory/network

processors:
  batch:

exporters:
  prometheusremotewrite:
    endpoint: http://mimir.<zone_internal>:9009/api/v1/push
  otlp:
    endpoint: tempo.<zone_internal>:4317
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
      exporters: [otlp]
```

Replace `<zone_internal>` with your Cloud Map private namespace (e.g. `lab.democorp.internal`).

---

## Dashboards

| Dashboard | File | Description |
|-----------|------|-------------|
| ECS Observability | `resources/dashboards/grafana-dashboard-ecs-observability.json` | Container-level CPU, memory, network per ECS service |
| JVM / Spring Boot | `resources/dashboards/grafana-dashboard-jvm-springboot.json` | Heap, GC, threads, CPU — filterable by service |
| Observability Integral | `resources/dashboards/grafana-dashboard-observability-integral.json` | Full stack overview: all services, resources, traces |

Edit the JSON files locally, then run `bash resources/sync-dashboards.sh` to push changes.
