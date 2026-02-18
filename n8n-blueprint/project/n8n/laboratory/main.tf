# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "project" {
  
  source  = "gocloudLa/standard-platform/aws//modules/project"
  version = "0.23.0"
  

  /*----------------------------------------------------------------------*/
  /* General Variables                                                    */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata


  ecs_parameters = {
    "00" = {
      cluster_settings = [{
        name  = "containerInsights"
        value = "disabled"
      }]
      default_capacity_provider_strategy = {
        FARGATE = {
          weight = 0
        }
        FARGATE_SPOT = {
          weight = 100
        }
      }
      autoscaling_capacity_providers = {}
    }
  }

  rds_parameters = {
    "pgsql-00" = {
      engine               = "postgres"
      engine_version       = "18"
      family               = "postgres18" # DB parameter group
      major_engine_version = "18"         # DB option group

      instance_class = "db.t4g.micro" # Most economical instance type (ARM-based)
      port           = "5432"

      # ALARMS CONFIGURATION
      enable_alarms = false # Default: false

      alarms_disabled = ["critical-CPUUtilization", "critical-EBSByteBalance", "critical-EBSIOBalance"] # if you need to disable an alarm

      # DEBUG
      deletion_protection = false
      apply_immediately   = true
      skip_final_snapshot = true

      subnet_ids          = data.aws_subnets.private.ids
      publicly_accessible = true
      ingress_with_cidr_blocks = [
        {
          rule        = "postgresql-tcp"
          cidr_blocks = "0.0.0.0/0"
        }
      ]

      dns_records = {
        "" = {
          zone_name    = local.zone_private
          private_zone = true
        }
      }
      # parameters = [
      #   {
      #     name  = "max_connections"
      #     value = "150"
      #   }
      # ]
      maintenance_window      = "Sun:04:00-Sun:06:00"
      backup_window           = "03:00-03:30"
      backup_retention_period = "7"
      apply_immediately       = true

      # DB MANAGEMENT
      enable_db_management                    = true
      enable_db_management_logs_notifications = true
      db_management_parameters = {
        databases = [
          {
            "name" : "n8n",
            "owner" : "n8n",
            "schemas" : [
              {
                "name" : "public",
                "owner" : "n8n"
              }
            ]
          }
        ],
        roles = [],
        users = [
          {
            "username" : "n8n",
            "password" : "${local.secrets.rds_n8n_password}",
            "grants" : [
              {
                "database" : "n8n",
                "schema" : "public",
                "privileges" : "ALL PRIVILEGES",
                "table" : "*"
              }
            ]
          }
        ],
        excluded_users = ["rdsadmin", "root", "healthcheck", "postgres"]
      }
    }
  }

  efs_parameters = {
    "00" = {
      access_points = {
        "root" = {
          root_directory = {
            path = "/"
            creation_info = {
              owner_gid   = 1001
              owner_uid   = 1001
              permissions = "755"
            }
          }
        }
        "n8n_data" = {
          root_directory = {
            path = "/n8n_data"
            creation_info = {
              owner_gid   = 1000
              owner_uid   = 1000
              permissions = "777"
            }
          }
        }
      }
    }
  }

}
