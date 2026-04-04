# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "base" {

  source = "git@github.com:gocloudLa/terraform-aws-standard-platform.git//modules/base?ref=feature/vpc-upgrade"


  /*----------------------------------------------------------------------*/
  /* General Variables                                                    */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata

  vpc_parameters = {
    "networking" = {
      vpc_cidr = "${local.vpc_cidr}"
      internet_gateway = {
        "igw" = {}
      }
      nat_gateway = {
        "natgw" = {
          subnet = "public-a"
          kind   = "aws" # OPCION AWS
        }
      }
      route_table = {
        "private" = {
          routes = {
          }
          default_route = {
            nat_gateway = "natgw"
          }
        }
        "public" = {
          routes = {
          }
          default_route = {
            gateway = "igw"
          }
        }
      }
      network_acl = {
        "private" = {
          rules = {}
        }
        "public" = {
          rules = {}
        }
      }
      subnets = {
        "private" = {
          "a" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 0)
            az          = "a"
            route_table = "private"
            network_acl = "private"
          }
          "b" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 1)
            az          = "b"
            route_table = "private"
            network_acl = "private"
          }
          "c" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 2)
            az          = "c"
            route_table = "private"
            network_acl = "private"
          }
        }
        "public" = {
          "a" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 3)
            az          = "a"
            route_table = "public"
            network_acl = "public"
          }
          "b" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 4)
            az          = "b"
            route_table = "public"
            network_acl = "public"
          }
          "c" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 5)
            az          = "c"
            route_table = "public"
            network_acl = "public"
          }
        }
        # "db" = {
        #   "a" = {
        #     cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 6)
        #     az          = "a"
        #     route_table = "private"
        #     network_acl = "private"
        #   }
        #   "b" = {
        #     cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 7)
        #     az          = "b"
        #     route_table = "private"
        #     network_acl = "private"
        #   }
        #   "c" = {
        #     cidr_block  = cidrsubnet("${local.vpc_cidr}", 4, 8)
        #     az          = "c"
        #     route_table = "private"
        #     network_acl = "private"
        #   }
        # }
      }
      endpoints = {
        "00" = {
          service         = "s3"
          service_type    = "Gateway"
          route_table_ids = ["private", "public"]
          policy          = data.aws_iam_policy_document.s3_endpoint_policy.json
        },
        "01" = {
          service         = "dynamodb"
          service_type    = "Gateway"
          route_table_ids = ["private", "public"]
          policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
        }
      }
    }
  }

  tgw_parameters = {
    "tgw-01" = {
      # Variables to deploy transit gateway resource

      create_tgw = true
      # create_tgw_routes = false

      # description                            = "Transit Gateway 01"
      amazon_side_asn = "64512"

      ## Allow the sharing of the TGW using RAM
      share_tgw      = true
      ram_principals = ["377730029539"]
      # ram_allow_external_principals = false
      # ram_name                      = null
      enable_auto_accept_shared_attachments = true

      ## Managing TGW VPC Attachments
      vpc_attachments = {
        "networking" = {
          subnet_ids                                      = ["private-a", "private-b", "private-c"]
          dns_support                                     = true
          ipv6_support                                    = false
          transit_gateway_default_route_table_association = true
          transit_gateway_default_route_table_propagation = true
          tgw_routes = [
            {
              destination_cidr_block = "10.20.0.0/16"

            },
            {
              blackhole              = true
              destination_cidr_block = "0.0.0.0/0"
            }
          ]
        }
      }
      # ## Managing route association of route tables of attached VPC's
      vpc_routes = {
        "networking" = {
          "private" = {
            destination_cidr_block = [
              "10.30.0.0/16",
            ]
          }
          "public" = {
            destination_cidr_block = [
              "10.30.0.0/16"
            ]
          }
        }
      }
    }
  }
}
