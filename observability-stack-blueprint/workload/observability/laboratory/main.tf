# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "workload" {

  source  = "gocloudLa/standard-platform/aws//modules/workload"
  version = "0.31.0"

  providers = {
    aws.use1 = aws.use1
  }

  /*----------------------------------------------------------------------*/
  /* General Parameters                                                   */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata

  /*----------------------------------------------------------------------*/
  /* ECS Service Parameters                                               */
  /*----------------------------------------------------------------------*/

  ecs_service_parameters = {
    grafana = {
      enable_autoscaling = false
      cpu                = 512
      memory             = 1024

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      tasks_iam_role_statements = [
        {
          actions = [
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:DescribeAlarmsForMetric"
          ]
          resources = ["*"]
        },
        {
          actions = [
            "logs:DescribeLogGroups",
            "logs:GetLogGroupFields",
            "logs:StartQuery",
            "logs:StopQuery",
            "logs:GetQueryResults",
            "logs:GetLogEvents"
          ]
          resources = ["*"]
        }
      ]

      containers = {
        app = {
          image                 = "grafana/grafana:13.0.1"
          create_ecr_repository = false

          ports = {
            "p1" = {
              container_port = 3000
              load_balancer = {
                main = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/api/health"
                    matcher = 200
                  }
                  dns_records = {
                    "grafana" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 310
                      conditions = [
                        {
                          host_headers = ["grafana.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            GF_AUTH_ANONYMOUS_ENABLED  = "false"
            GF_SERVER_ROOT_URL         = "https://grafana.${local.zone_public}"
            GF_SECURITY_ADMIN_PASSWORD = "admin"
            GF_SECURITY_ADMIN_USER     = "admin"
          }
        }
      }
    }

    tempo = {
      enable_autoscaling = false
      cpu                = 256
      memory             = 512

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      tasks_iam_role_statements = [
        {
          actions = [
            "s3:ListBucket"
          ]
          resources = [data.aws_s3_bucket.tempo_traces.arn]
        },
        {
          actions = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          resources = ["${data.aws_s3_bucket.tempo_traces.arn}/*"]
        }
      ]

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/alpine:3.21"
          create_ecr_repository = false

          ports = {
            "http" = { container_port = 3200 }
            "otlp_grpc" = {
              container_port = 4317
              service_discovery = {
                record_name    = "tempo"
                namespace_name = local.zone_internal
              }
            }
            "otlp_http" = { container_port = 4318 }
          }

          map_environment = {
            "CONFIG_FILE" = <<-EOT
              server:
                http_listen_port: 3200
              distributor:
                receivers:
                  otlp:
                    protocols:
                      grpc:
                        endpoint: 0.0.0.0:4317
                      http:
                        endpoint: 0.0.0.0:4318
              storage:
                trace:
                  backend: s3
                  s3:
                    bucket: ${data.aws_s3_bucket.tempo_traces.bucket}
                    region: ${local.metadata.aws_region}
                    endpoint: s3.${local.metadata.aws_region}.amazonaws.com
              compactor:
                compaction:
                  block_retention: 4320h
            EOT
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache wget
              wget -q -O /tmp/tempo.tar.gz https://github.com/grafana/tempo/releases/download/v2.7.2/tempo_2.7.2_linux_amd64.tar.gz
              tar -xzf /tmp/tempo.tar.gz -C /tmp
              chmod +x /tmp/tempo
              echo "$CONFIG_FILE" > /tmp/tempo.yaml
              exec /tmp/tempo -config.file=/tmp/tempo.yaml
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }
      }
    }

    mimir = {
      enable_autoscaling = false
      cpu                = 512
      memory             = 1024

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      tasks_iam_role_statements = [
        {
          actions = [
            "s3:ListBucket"
          ]
          resources = [data.aws_s3_bucket.mimir_blocks.arn]
        },
        {
          actions = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          resources = ["${data.aws_s3_bucket.mimir_blocks.arn}/*"]
        }
      ]

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/alpine:3.21"
          create_ecr_repository = false

          ports = {
            "http" = {
              container_port = 9009
              service_discovery = {
                record_name    = "mimir"
                namespace_name = local.zone_internal
              }
            }
          }

          map_environment = {
            "CONFIG_FILE" = <<-EOT
              multitenancy_enabled: false

              server:
                http_listen_port: 9009

              ingester:
                ring:
                  replication_factor: 1
                  kvstore:
                    store: inmemory

              store_gateway:
                sharding_ring:
                  replication_factor: 1
                  kvstore:
                    store: inmemory
                  wait_stability_min_duration: 0s
                  wait_stability_max_duration: 0s

              compactor:
                sharding_ring:
                  kvstore:
                    store: inmemory
                data_dir: /tmp/data/compactor

              common:
                storage:
                  backend: s3
                  s3:
                    region: ${local.metadata.aws_region}
                    endpoint: s3.${local.metadata.aws_region}.amazonaws.com
                    bucket_name: ${data.aws_s3_bucket.mimir_blocks.bucket}
                    native_aws_auth_enabled: true

              blocks_storage:
                backend: s3
                s3:
                  bucket_name: ${data.aws_s3_bucket.mimir_blocks.bucket}
                  endpoint: s3.${local.metadata.aws_region}.amazonaws.com
                tsdb:
                  dir: /tmp/data/tsdb
                  block_ranges_period: [30m]
                  ship_interval: 1m
                  head_compaction_interval: 5m
                bucket_store:
                  sync_dir: /tmp/data/tsdb-sync
                  sync_interval: 5m

              ruler_storage:
                backend: filesystem
                filesystem:
                  dir: /tmp/data/rules

              alertmanager_storage:
                backend: filesystem
                filesystem:
                  dir: /tmp/data/alertmanager

              limits:
                compactor_blocks_retention_period: 4320h
            EOT
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache wget
              wget -q -O /tmp/mimir https://github.com/grafana/mimir/releases/download/mimir-2.15.1/mimir-linux-amd64
              chmod +x /tmp/mimir
              mkdir -p /tmp/data
              echo "$CONFIG_FILE" > /tmp/mimir.yaml
              exec /tmp/mimir -config.file=/tmp/mimir.yaml
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }
      }
    }

    loki = {
      enable_autoscaling = false
      cpu                = 512
      memory             = 1024

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      tasks_iam_role_statements = [
        {
          actions = [
            "s3:ListBucket"
          ]
          resources = [data.aws_s3_bucket.loki_chunks.arn]
        },
        {
          actions = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          resources = ["${data.aws_s3_bucket.loki_chunks.arn}/*"]
        }
      ]

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/alpine:3.21"
          create_ecr_repository = false

          ports = {
            "http" = {
              container_port = 3100
              service_discovery = {
                record_name    = "loki"
                namespace_name = local.zone_internal
              }
            }
          }

          map_environment = {
            "CONFIG_FILE" = <<-EOT
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
                  region: ${local.metadata.aws_region}
                  bucketnames: ${data.aws_s3_bucket.loki_chunks.bucket}
                  s3forcepathstyle: false

              compactor:
                working_directory: /tmp/loki/compactor
                delete_request_store: s3
                retention_enabled: true

              limits_config:
                retention_period: 720h
                allow_structured_metadata: true
            EOT
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache wget
              wget -q -O /tmp/loki.zip https://github.com/grafana/loki/releases/download/v3.4.2/loki-linux-amd64.zip
              unzip /tmp/loki.zip -d /tmp
              chmod +x /tmp/loki-linux-amd64
              mkdir -p /tmp/loki
              echo "$CONFIG_FILE" > /tmp/loki.yaml
              exec /tmp/loki-linux-amd64 -config.file=/tmp/loki.yaml
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }
      }
    }

    alloy = {
      enable_autoscaling = false
      cpu                = 256
      memory             = 512

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/alpine:3.21"
          create_ecr_repository = false

          ports = {
            "p1" = {
              container_port = 12347
              load_balancer = {
                "l1" = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/collect"
                    matcher = "200,404,405"
                  }
                  dns_records = {
                    "alloy" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 350
                      conditions = [
                        {
                          host_headers = ["alloy.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            "CONFIG_FILE" = <<-EOT
              faro.receiver "default" {
                server {
                  listen_address           = "0.0.0.0"
                  listen_port              = 12347
                  cors_allowed_origins     = ["*"]
                  max_allowed_payload_size = "10MiB"
                }

                extra_log_labels = {
                  app_name        = "",
                  app_environment = "",
                  app_namespace   = "",
                  app_version     = "",
                  source          = "faro",
                }

                log_format = "json"

                output {
                  logs   = [loki.write.default.receiver]
                  traces = [otelcol.exporter.otlp.tempo.input]
                }
              }

              loki.write "default" {
                endpoint {
                  url = "http://loki.${local.zone_internal}:3100/loki/api/v1/push"
                }
              }

              otelcol.exporter.otlp "tempo" {
                client {
                  endpoint = "tempo.${local.zone_internal}:4317"
                  tls {
                    insecure = true
                  }
                }
              }
            EOT
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache wget gcompat
              wget -q -O /tmp/alloy.zip https://github.com/grafana/alloy/releases/download/v1.16.1/alloy-linux-amd64.zip
              unzip /tmp/alloy.zip -d /tmp
              chmod +x /tmp/alloy-linux-amd64
              mkdir -p /tmp/alloy-data
              echo "$CONFIG_FILE" > /tmp/config.alloy
              exec /tmp/alloy-linux-amd64 run /tmp/config.alloy --storage.path=/tmp/alloy-data --server.http.listen-addr=0.0.0.0:12345
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }
      }
    }

    demo-frontend = {
      enable_autoscaling = false
      cpu                = 256
      memory             = 512

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/nginx:alpine"
          create_ecr_repository = false

          ports = {
            "p1" = {
              container_port = 80
              load_balancer = {
                "l1" = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/"
                    matcher = "200"
                  }
                  dns_records = {
                    "demo-frontend" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 360
                      conditions = [
                        {
                          host_headers = ["demo-frontend.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            "CONFIG_FILE" = <<-EOT
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Demo Frontend — Faro RUM</title>
                <style>
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #1a1a2e; color: #eee; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 2rem; }
                  .card { background: #16213e; border-radius: 12px; padding: 2rem; max-width: 600px; width: 100%; box-shadow: 0 4px 20px rgba(0,0,0,0.3); }
                  h1 { color: #f77f00; margin-bottom: 1rem; }
                  p { line-height: 1.6; margin-bottom: 1rem; color: #ccc; }
                  .btn { display: inline-block; padding: 0.75rem 1.5rem; margin: 0.5rem 0.5rem 0.5rem 0; border: none; border-radius: 6px; cursor: pointer; font-size: 0.9rem; font-weight: 600; transition: transform 0.1s; }
                  .btn:active { transform: scale(0.95); }
                  .btn-error { background: #e63946; color: white; }
                  .btn-log { background: #457b9d; color: white; }
                  .btn-fetch { background: #2a9d8f; color: white; }
                  .btn-nav { background: #e9c46a; color: #1a1a2e; }
                  #output { margin-top: 1rem; padding: 1rem; background: #0f3460; border-radius: 8px; font-family: monospace; font-size: 0.85rem; min-height: 60px; white-space: pre-wrap; }
                  .status { margin-top: 1rem; padding: 0.5rem 1rem; background: #2a9d8f22; border: 1px solid #2a9d8f; border-radius: 6px; font-size: 0.8rem; }
                </style>
                <script>
                  window.initFaro = function() {
                    window.faro = window.GrafanaFaroWebSdk.initializeFaro({
                      url: 'https://alloy.${local.zone_public}/collect',
                      app: { name: 'demo-frontend', version: '1.0.0', environment: 'laboratory' },
                      instrumentations: [
                        ...window.GrafanaFaroWebSdk.getWebInstrumentations({ captureConsole: true }),
                      ],
                    });
                    document.getElementById('status').textContent = 'Faro SDK initialized — sending telemetry to Alloy';
                  };
                  window.addFaroTracing = function() {
                    if (window.faro) {
                      window.faro.instrumentations.add(new window.GrafanaFaroWebTracing.TracingInstrumentation());
                      document.getElementById('status').textContent += ' | Tracing enabled';
                    }
                  };
                </script>
              </head>
              <body>
                <div class="card">
                  <h1>Demo Frontend — Faro RUM</h1>
                  <p>This page is instrumented with Grafana Faro Web SDK. It sends Web Vitals, errors, console logs, and traces to Grafana Alloy.</p>
                  <button class="btn btn-error" onclick="throwError()">Throw Error</button>
                  <button class="btn btn-log" onclick="sendLog()">Console Log</button>
                  <button class="btn btn-fetch" onclick="doFetch()">Fetch API Call</button>
                  <button class="btn btn-error" onclick="fetchWithError()">Fetch + Error</button>
                  <button class="btn btn-nav" onclick="simulateNav()">Simulate Navigation</button>
                  <div id="output">Ready. Click buttons to generate telemetry...</div>
                  <div class="status" id="status">Loading Faro SDK...</div>
                </div>
                <script>
                  function log(msg) { document.getElementById('output').textContent = new Date().toISOString() + ' ' + msg; }
                  function throwError() { try { undefinedFunction(); } catch(e) { window.faro && window.faro.api.pushError(e); log('Error thrown and reported to Faro'); } }
                  function sendLog() { console.log('User action: manual log at ' + new Date().toISOString()); log('Console.log sent (captured by Faro)'); }
                  function doFetch() { fetch('https://httpbin.org/delay/1').then(r => { log('Fetch completed: ' + r.status); }).catch(e => { log('Fetch failed: ' + e.message); }); }
                  function fetchWithError() { fetch('https://httpbin.org/json').then(r => r.json()).then(data => { data.nonExistent.property; }).catch(e => { log('Fetch + Error: ' + e.message); }); }
                  function simulateNav() { history.pushState({}, '', '/page-' + Math.floor(Math.random()*100)); log('Navigation event: ' + location.pathname); setTimeout(() => history.pushState({}, '', '/'), 1000); }
                </script>
                <script src="https://unpkg.com/@grafana/faro-web-sdk@^1.0.0/dist/bundle/faro-web-sdk.iife.js" onload="window.initFaro()"></script>
                <script src="https://unpkg.com/@grafana/faro-web-tracing@^1.0.0/dist/bundle/faro-web-tracing.iife.js" onload="window.addFaroTracing()"></script>
              </body>
              </html>
            EOT
            "COMMAND" = <<-EOT
              set -e
              echo "$CONFIG_FILE" > /usr/share/nginx/html/index.html
              exec nginx -g 'daemon off;'
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }

        otel-sidecar = {
          image                 = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3"
          create_ecr_repository = false

          ports = {
            "otlp_grpc" = { container_port = 4317 }
            "otlp_http" = { container_port = 4318 }
          }

          map_environment = {
            "AOT_CONFIG_CONTENT" = <<-EOT
              receivers:
                awsecscontainermetrics:

              processors:
                batch:

              exporters:
                prometheusremotewrite:
                  endpoint: http://mimir.${local.zone_internal}:9009/api/v1/push
                  resource_to_telemetry_conversion:
                    enabled: true

              service:
                pipelines:
                  metrics:
                    receivers: [awsecscontainermetrics]
                    processors: [batch]
                    exporters: [prometheusremotewrite]
            EOT
          }
        }
      }
    }

    demo-java = {
      enable_autoscaling = false
      cpu                = 1024
      memory             = 2048
      health_check_grace_period_seconds = 360

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/amazoncorretto:21-alpine"
          create_ecr_repository = false

          ports = {
            "http" = {
              container_port = 8080
              load_balancer = {
                main = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/actuator/health"
                    matcher = 200
                  }
                  dns_records = {
                    "demo-java" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 340
                      conditions = [
                        {
                          host_headers = ["demo-java.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            OTEL_SERVICE_NAME           = "${local.common_name}-demo-java"
            OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4317"
            OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
            OTEL_METRICS_EXPORTER       = "otlp"
            OTEL_TRACES_EXPORTER        = "otlp"
            OTEL_LOGS_EXPORTER          = "otlp"
            OTEL_RESOURCE_ATTRIBUTES    = "deployment.environment=lab"
            OTEL_TRACES_SAMPLER         = "always_on"
            OTEL_METRIC_EXPORT_INTERVAL = "10000"
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache wget
              wget -q -O /tmp/opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar
              wget -q -O /tmp/app.jar https://repo1.maven.org/maven2/io/zipkin/zipkin-server/3.4.2/zipkin-server-3.4.2-exec.jar
              exec java -javaagent:/tmp/opentelemetry-javaagent.jar -DQUERY_PORT=8080 -Dserver.port=8080 -jar /tmp/app.jar
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }

        otel-sidecar = {
          image                 = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3"
          create_ecr_repository = false

          ports = {
            "otlp_grpc" = { container_port = 4317 }
            "otlp_http" = { container_port = 4318 }
          }

          map_environment = {
            "AOT_CONFIG_CONTENT" = <<-EOT
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
                  endpoint: http://mimir.${local.zone_internal}:9009/api/v1/push
                  resource_to_telemetry_conversion:
                    enabled: true
                otlp/traces:
                  endpoint: tempo.${local.zone_internal}:4317
                  tls:
                    insecure: true
                otlphttp/logs:
                  endpoint: http://loki.${local.zone_internal}:3100/otlp
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
            EOT
          }
        }
      }
    }

    demo-nodejs = {
      enable_autoscaling = false
      cpu                = 256
      memory             = 512

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/node:22-alpine"
          create_ecr_repository = false

          ports = {
            "p1" = {
              container_port = 3000
              load_balancer = {
                "l1" = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/health"
                    matcher = 200
                  }
                  dns_records = {
                    "demo-nodejs" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 320
                      conditions = [
                        {
                          host_headers = ["demo-nodejs.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            OTEL_SERVICE_NAME           = "${local.common_name}-demo-nodejs"
            OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4317"
            OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
            OTEL_METRICS_EXPORTER       = "otlp"
            OTEL_TRACES_EXPORTER        = "otlp"
            OTEL_LOGS_EXPORTER          = "otlp"
            OTEL_RESOURCE_ATTRIBUTES    = "deployment.environment=lab"
            OTEL_TRACES_SAMPLER         = "always_on"
            OTEL_METRIC_EXPORT_INTERVAL = "10000"
            "COMMAND" = <<-EOT
              set -e
              cd /tmp
              rm -rf node_modules package-lock.json package.json
              npm init -y
              npm install --save express @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-metrics-otlp-grpc @opentelemetry/exporter-trace-otlp-grpc
              cat > tracing.js << 'EOF'
              const { NodeSDK } = require('@opentelemetry/sdk-node');
              const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
              const sdk = new NodeSDK({ instrumentations: [getNodeAutoInstrumentations()] });
              sdk.start();
              EOF
              cat > app.js << 'EOF'
              const express = require('express');
              const app = express();
              app.get('/', (req, res) => res.json({ status: 'ok', service: 'demo-nodejs' }));
              app.get('/health', (req, res) => res.json({ status: 'healthy' }));
              app.get('/work', (req, res) => {
                const start = Date.now();
                while (Date.now() - start < 50) {}
                res.json({ status: 'done', duration_ms: Date.now() - start });
              });
              app.listen(3000, () => console.log('Listening on 3000'));
              EOF
              node -r ./tracing.js app.js
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }

        otel-sidecar = {
          image                 = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3"
          create_ecr_repository = false

          ports = {
            "otlp_grpc" = { container_port = 4317 }
            "otlp_http" = { container_port = 4318 }
          }

          map_environment = {
            "AOT_CONFIG_CONTENT" = <<-EOT
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
                  endpoint: http://mimir.${local.zone_internal}:9009/api/v1/push
                  resource_to_telemetry_conversion:
                    enabled: true
                otlp/traces:
                  endpoint: tempo.${local.zone_internal}:4317
                  tls:
                    insecure: true
                otlphttp/logs:
                  endpoint: http://loki.${local.zone_internal}:3100/otlp
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
            EOT
          }
        }
      }
    }

    demo-php = {
      enable_autoscaling = false
      cpu                = 256
      memory             = 512
      health_check_grace_period_seconds = 180

      capacity_provider_strategy = {
        default = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      containers = {
        app = {
          image                 = "public.ecr.aws/docker/library/php:8.3-cli-alpine"
          create_ecr_repository = false

          ports = {
            "p1" = {
              container_port = 8080
              load_balancer = {
                "l1" = {
                  alb_name          = data.aws_lb.public_alb.name
                  alb_listener_port = 443
                  health_check = {
                    path    = "/"
                    matcher = 200
                  }
                  dns_records = {
                    "demo-php" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "r1" = {
                      priority = 330
                      conditions = [
                        {
                          host_headers = ["demo-php.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }

          map_environment = {
            OTEL_PHP_AUTOLOAD_ENABLED      = "true"
            OTEL_SERVICE_NAME              = "${local.common_name}-demo-php"
            OTEL_EXPORTER_OTLP_ENDPOINT    = "http://127.0.0.1:4318"
            OTEL_EXPORTER_OTLP_PROTOCOL    = "http/protobuf"
            OTEL_TRACES_EXPORTER           = "otlp"
            OTEL_METRICS_EXPORTER          = "otlp"
            OTEL_LOGS_EXPORTER             = "otlp"
            OTEL_RESOURCE_ATTRIBUTES       = "deployment.environment=lab"
            OTEL_TRACES_SAMPLER            = "always_on"
            "COMMAND" = <<-EOT
              set -e
              apk add --no-cache autoconf gcc g++ make php83-dev php83-openssl php83-curl composer
              pecl install opentelemetry
              docker-php-ext-enable opentelemetry
              mkdir -p /tmp/app
              composer require --ignore-platform-reqs --working-dir=/tmp/app \
                open-telemetry/sdk \
                open-telemetry/exporter-otlp \
                php-http/guzzle7-adapter
              cat > /tmp/app/index.php << 'EOF'
              <?php
              require 'vendor/autoload.php';
              $host = '0.0.0.0';
              $port = 8080;
              $socket = stream_socket_server("tcp://$host:$port", $errno, $errstr);
              if (!$socket) { die("Error: $errstr ($errno)\n"); }
              echo "PHP demo listening on $host:$port\n";
              while ($conn = stream_socket_accept($socket, -1)) {
                $request = fread($conn, 1024);
                $body = json_encode(['status' => 'ok', 'service' => 'demo-php', 'time' => date('c')]);
                $response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " . strlen($body) . "\r\n\r\n$body";
                fwrite($conn, $response);
                fclose($conn);
              }
              EOF
              cd /tmp/app && php index.php
            EOT
          }

          entrypoint = [""]
          command    = ["/bin/sh", "-c", "eval \"$COMMAND\""]
        }

        otel-sidecar = {
          image                 = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.3"
          create_ecr_repository = false

          ports = {
            "otlp_grpc" = { container_port = 4317 }
            "otlp_http" = { container_port = 4318 }
          }

          map_environment = {
            "AOT_CONFIG_CONTENT" = <<-EOT
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
                  endpoint: http://mimir.${local.zone_internal}:9009/api/v1/push
                  resource_to_telemetry_conversion:
                    enabled: true
                otlp/traces:
                  endpoint: tempo.${local.zone_internal}:4317
                  tls:
                    insecure: true
                otlphttp/logs:
                  endpoint: http://loki.${local.zone_internal}:3100/otlp
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
            EOT
          }
        }
      }
    }
  }
}
