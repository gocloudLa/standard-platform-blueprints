# =============================================================================
# This file is generated and maintained by GoCloud CLI
# You CAN edit this file manually to add your custom configuration
# GoCloud CLI will only update the module version when needed
# =============================================================================

module "base" {

  source  = "gocloudLa/standard-platform/aws//modules/base"
  version = "1.10.0"

  /*----------------------------------------------------------------------*/
  /* General Parameters                                                   */
  /*----------------------------------------------------------------------*/

  metadata = local.metadata

  vpc_parameters = {
    "production" = {
      vpc_cidr = "${local.vpc_cidr}"
      internet_gateway = {
        "igw" = {}
      }
      nat_gateway = {
        "natgw" = {
          subnet = "public-a"
          kind   = "aws"
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
    "development" = {
      vpc_cidr = "${local.vpc_cidr_development}"
      custom_common_name = "${local.common_name}-dev"
      internet_gateway = {
        "igw" = {}
      }
      nat_gateway = {
        # Managed NAT alternative: kind = "aws" and default_route.nat_gateway = "natgw".
        # "natgw" = {
        #   subnet = "public-a"
        #   kind   = "aws"
        # }
        "natgw" = {
          subnet = "public-a"
          kind   = "ec2"
          nat_parameters = {
            ec2_nat_gateway_attach_eip = true,
            ingress_with_cidr_blocks = [
              {
                rule = "all-all",
                cidr_blocks = "10.20.0.0/16,10.30.0.0/16,10.40.0.0/16,10.50.0.0/16,10.60.0.0/16"
              }
            ]
          }
        }
      }
      route_table = {
        "private" = {
          routes = {
          }
          default_route = {
            # nat_gateway = "natgw"
            network_interface = "natgw"
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
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 0)
            az          = "a"
            route_table = "private"
            network_acl = "private"
          }
          "b" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 1)
            az          = "b"
            route_table = "private"
            network_acl = "private"
          }
          "c" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 2)
            az          = "c"
            route_table = "private"
            network_acl = "private"
          }
        }
        "public" = {
          "a" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 3)
            az          = "a"
            route_table = "public"
            network_acl = "public"
          }
          "b" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 4)
            az          = "b"
            route_table = "public"
            network_acl = "public"
          }
          "c" = {
            cidr_block  = cidrsubnet("${local.vpc_cidr_development}", 4, 5)
            az          = "c"
            route_table = "public"
            network_acl = "public"
          }
        }
      }
      endpoints = {}
    }
  }

  peering_parameters = {
    # Optional same-account peering between production and development.
    # "prd-with-dev" = {
    #   # create_peer = true
    #   auto_accept  = true
    #   vpc          = "production"
    #   # vpc_id = "vpc-01234567890123456"
    #   vpc_accepter = "development"
    #   # vpc_accepter_id = "vpc-01234567890123456"
    #   vpc_routes = {
    #     "production" = {
    #       "private" = { destination_cidr_block = [local.vpc_cidr_development] }
    #       "public"  = { destination_cidr_block = [local.vpc_cidr_development] }
    #     }
    #     "development" = {
    #       "private" = { destination_cidr_block = [local.vpc_cidr] }
    #       "public"  = { destination_cidr_block = [local.vpc_cidr] }
    #     }
    #   }
    # }

    # Optional cross-account accepter. Uncomment after lab_vpc_net creates the peering.
    # "net-with-dev" = {
    #   create_peer = false
    #   vpc         = "development"
    #   auto_accept = true
    #   peering_id  = "pcx-0f867af7fee4963c1"
    #
    #   # Enable after the peering is active.
    #   # accepter = { allow_remote_vpc_dns_resolution = true }
    #
    #   vpc_routes = {
    #     "development" = {
    #       "private" = { destination_cidr_block = ["10.20.0.0/16"] }
    #       "public"  = { destination_cidr_block = ["10.20.0.0/16"] }
    #     }
    #   }
    # }
  }

  # Optional attachment to the TGW shared from lab_vpc_net.
  # create_tgw = false looks up that gateway by amazon_side_asn (a list). Omit it to use the wrapper default ["64512"].
  # tgw_parameters = {
  #   "tgw-01" = {
  #     create_tgw = false
  #
  #     vpc_attachments = {
  #       "production" = {
  #         subnet_ids = ["private-a", "private-b", "private-c"]
  #         tgw_routes = [
  #           {
  #             destination_cidr_block = "10.30.0.0/16"

  #           },
  #           {
  #             blackhole              = true
  #             destination_cidr_block = "0.0.0.0/0"
  #           }
  #         ]
  #       }
  #     }
  #     vpc_routes = {
  #       "production" = {
  #         "private" = {
  #           destination_cidr_block = [
  #             "10.20.0.0/16"
  #           ]
  #         }
  #         "public" = {
  #           destination_cidr_block = [
  #             "10.20.0.0/16"
  #           ]
  #         }
  #       }
  #     }
  #   }
  # }
}
