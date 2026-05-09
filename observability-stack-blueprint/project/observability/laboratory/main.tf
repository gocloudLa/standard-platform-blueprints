# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "project" {

  source  = "gocloudLa/standard-platform/aws//modules/project"
  version = "0.31.0"


  /*----------------------------------------------------------------------*/
  /* General Parameters                                                   */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata

  /*----------------------------------------------------------------------*/
  /* ECS Parameters                                                       */
  /*----------------------------------------------------------------------*/

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

  /*----------------------------------------------------------------------*/
  /* Bucket Parameters                                                    */
  /*----------------------------------------------------------------------*/
  bucket_parameters = {
    "mimir-blocks" = {
      create_bucket                 = true
      enable_s3_public_access_block = true
      block_public_acls             = true
      block_public_policy           = true
      ignore_public_acls            = true
      restrict_public_buckets       = true
      object_ownership              = "BucketOwnerEnforced"
    }
    "tempo-traces" = {
      create_bucket                 = true
      enable_s3_public_access_block = true
      block_public_acls             = true
      block_public_policy           = true
      ignore_public_acls            = true
      restrict_public_buckets       = true
      object_ownership              = "BucketOwnerEnforced"
    }
    "loki-chunks" = {
      create_bucket                 = true
      enable_s3_public_access_block = true
      block_public_acls             = true
      block_public_policy           = true
      ignore_public_acls            = true
      restrict_public_buckets       = true
      object_ownership              = "BucketOwnerEnforced"
    }
  }

}
