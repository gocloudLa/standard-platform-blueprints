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
                    store: memberlist

              store_gateway:
                sharding_ring:
                  replication_factor: 1
                  kvstore:
                    store: memberlist

              compactor:
                sharding_ring:
                  kvstore:
                    store: memberlist
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
                bucket_store:
                  sync_dir: /tmp/data/tsdb-sync

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
              pecl install opentelemetry
              docker-php-ext-enable opentelemetry
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
