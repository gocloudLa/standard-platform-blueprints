# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "workload" {
  
  source  = "gocloudLa/standard-platform/aws//modules/workload"
  version = "0.23.0"
  

  providers = {
    aws.use1 = aws.use1
  }

  /*----------------------------------------------------------------------*/
  /* General Variables                                                    */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata

  /*----------------------------------------------------------------------*/
  /* ECS Service Parameters                                               */
  /*----------------------------------------------------------------------*/

  ecs_service_parameters = {
    n8n = {
      enable_autoscaling = false

      enable_execute_command = true

      capacity_provider_strategy = {
        fargate_spot = {
          base              = null
          capacity_provider = "FARGATE_SPOT"
          weight            = 100
        }
      }

      # Policies que usan la tasks desde el codigo desarrollado
      tasks_iam_role_policies   = {}
      tasks_iam_role_statements = []
      # Policies que usa el servicio para poder iniciar tasks (ecr / ssm / etc)
      task_exec_iam_role_policies = {}
      task_exec_iam_statements    = []

      ecs_task_volume_efs = {
        n8n_data = {
          efs_name     = "${local.common_name}-00"
          access_point = "n8n_data"
        }
      }

      containers = {
        app = {
          image = "docker.n8n.io/n8nio/n8n"

          map_environment = {
            # Database Configuration
            # https://docs.n8n.io/hosting/configuration/supported-databases-settings/
            "DB_TYPE"                = "postgresdb"
            "DB_POSTGRESDB_DATABASE" = "n8n"
            "DB_POSTGRESDB_HOST"     = "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["host"]}"
            "DB_POSTGRESDB_PORT"     = "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["port"]}"
            "DB_POSTGRESDB_USER"     = "n8n"
            "DB_POSTGRESDB_SCHEMA"   = "public"
            
            # SSL Configuration for PostgreSQL (required for RDS)
            "DB_POSTGRESDB_SSL"                    = "true"
            "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED" = "false"
            
            # Timezone and Localization
            # https://docs.n8n.io/hosting/configuration/environment-variables/timezone-localization/
            "GENERIC_TIMEZONE" = "America/Argentina/Buenos_Aires"
            
            # Server Configuration (for reverse proxy)
            # https://docs.n8n.io/hosting/configuration/environment-variables/deployment/
            "N8N_HOST"            = "n8n.${local.zone_public}"
            "N8N_PORT"            = "5678"
            "N8N_PROTOCOL"         = "https"
            "N8N_EDITOR_BASE_URL"  = "https://n8n.${local.zone_public}/"
            "WEBHOOK_URL"          = "https://n8n.${local.zone_public}/"
            "N8N_PROXY_HOPS"       = "1"
            
            # Logging Configuration
            # https://docs.n8n.io/hosting/configuration/environment-variables/logs/
            "N8N_LOG_LEVEL" = "info"
            
            # Tini Configuration (to suppress warning about subreaper)
            "TINI_SUBREAPER" = "1"

            "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS" = "false"
          }
          map_secrets = {
            # Database password
            "DB_POSTGRESDB_PASSWORD" = local.secrets.n8n_db_postgresdb_password
            
            # Encryption key for credentials
            # https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/
            "N8N_ENCRYPTION_KEY" = local.secrets.n8n_encryption_key
          }
          mount_points_efs = {
            n8n_data = {
              container_path = "/home/node/.n8n"
              read_only      = false
            }
          }
          ports = {
            "port1" = {
              container_port = 5678
              load_balancer = {
                "alb1" = {
                  target_group_custom_name = "${local.common_name}-n8n"

                  alb_name             = "dmc-lab-core-external-00"
                  alb_listener_port    = 443
                  deregistration_delay = 60
                  health_check         = {
                    path    = "/"
                    matcher = 200
                  }
                  dns_records = {
                    "n8n" = {
                      zone_name    = "${local.zone_public}"
                      private_zone = false
                    }
                  }
                  listener_rules = {
                    "rule1" = {
                      conditions = [
                        {
                          host_headers = ["n8n.${local.zone_public}"]
                        }
                      ]
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    # petstore = {
    #   enable_autoscaling = false

    #   enable_execute_command = true

    #   # Minimum task size for Fargate (256 CPU = 0.25 vCPU, 512 MB memory)
    #   cpu    = 256
    #   memory = 512

    #   capacity_provider_strategy = {
    #     fargate_spot = {
    #       base              = null
    #       capacity_provider = "FARGATE_SPOT"
    #       weight            = 100
    #     }
    #   }

    #   # Policies que usan la tasks desde el codigo desarrollado
    #   tasks_iam_role_policies   = {}
    #   tasks_iam_role_statements = []
    #   # Policies que usa el servicio para poder iniciar tasks (ecr / ssm / etc)
    #   task_exec_iam_role_policies = {}
    #   task_exec_iam_statements    = []

    #   containers = {
    #     app = {
    #       image                 = "ckanthony/openapi-mcp:latest"
    #       create_ecr_repository = false

    #       # Command arguments for openapi-mcp container
    #       # Using Petstore API (official Swagger/OpenAPI example) - no authentication required
    #       # https://github.com/ckanthony/openapi-mcp
    #       command = [
    #         "--spec",
    #         "https://petstore.swagger.io/v2/swagger.json",
    #         "--port",
    #         "8080"
    #       ]

    #       map_environment = {}
    #       map_secrets     = {}

    #       ports = {
    #         "port1" = {
    #           container_port = 8080
    #           # Service Discovery configuration for CloudMap
    #           service_discovery = {
    #             record_name    = "petstore"
    #             namespace_name = local.zone_internal
    #           }
    #         }
    #       }
    #     }
    #   }
    # }

    # georef = {
    #   enable_autoscaling = false

    #   enable_execute_command = true

    #   # Minimum task size for Fargate (256 CPU = 0.25 vCPU, 512 MB memory)
    #   cpu    = 256
    #   memory = 512

    #   capacity_provider_strategy = {
    #     fargate_spot = {
    #       base              = null
    #       capacity_provider = "FARGATE_SPOT"
    #       weight            = 100
    #     }
    #   }

    #   # Policies que usan la tasks desde el codigo desarrollado
    #   tasks_iam_role_policies   = {}
    #   tasks_iam_role_statements = []
    #   # Policies que usa el servicio para poder iniciar tasks (ecr / ssm / etc)
    #   task_exec_iam_role_policies = {}
    #   task_exec_iam_statements    = []

    #   containers = {
    #     app = {
    #       image                 = "ckanthony/openapi-mcp:latest"
    #       create_ecr_repository = false

    #       # Command arguments for openapi-mcp container
    #       # Using Georef Argentina API - no authentication required
    #       # https://www.argentina.gob.ar/georef/referencia-completa-de-la-api-georef-v-2
    #       # https://github.com/ckanthony/openapi-mcp
    #       # Using master branch instead of development as it may have a more stable spec
    #       command = [
    #         "--spec",
    #         "https://raw.githubusercontent.com/datosgobar/georef-ar-api/master/docs/open-api/spec/openapi.json",
    #         "--port",
    #         "8080"
    #       ]

    #       map_environment = {}
    #       map_secrets     = {}

    #       ports = {
    #         "port1" = {
    #           container_port = 8080
    #           # Service Discovery configuration for CloudMap
    #           service_discovery = {
    #             record_name    = "georef"
    #             namespace_name = local.zone_internal
    #           }
    #         }
    #       }
    #     }
    #   }
    # }
  }

}
