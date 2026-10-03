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
    "networking" = {
      vpc_cidr = "${local.vpc_cidr}"
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
  }

  peering_parameters = {
    # Optional cross-account peering. Uncomment after both VPCs exist.
    # Accepter is the commented "net-with-dev" block in base/lab_vpc_ac1.
    # "net-with-dev" = {
    #   create_peer = true
    #   vpc         = "networking"
    #
    #   # Enable after the peering is active. The requester cannot set accepter DNS options.
    #   # requester = { allow_remote_vpc_dns_resolution = true }
    #
    #   vpc_accepter_id = "vpc-06a4a7780e388980d"
    #   peer_owner_id   = "377730029539"
    #
    #   vpc_routes = {
    #     "networking" = {
    #       "private" = { destination_cidr_block = ["10.40.0.0/16"] }
    #       "public"  = { destination_cidr_block = ["10.40.0.0/16"] }
    #     }
    #   }
    # }
  }


  tgw_parameters = {
    "tgw-01" = {
      create_tgw = true
      # create_tgw_routes = false

      # description     = "Transit Gateway 01"
      amazon_side_asn = "64512"

      share_tgw      = true
      ram_principals = ["377730029539"] # lab_vpc_ac1 account
      # ram_allow_external_principals = false
      # ram_name                      = null
      enable_auto_accept_shared_attachments = true

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
      # Routes in this VPC toward the remote CIDR via the TGW.
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

  # Optional Site-to-Site VPN. Replace the customer gateway IP, CIDRs, and preshared keys before uncommenting.
  # vpn_parameters = {
  #   "vpn-vpc" = {
  #     vpc = "networking" # Key in vpc_parameters
  #     virtual_private_gateway = {
  #     }
  #     customer_gateway = {
  #       ip_address = "111.111.111.111" # Public IP of the customer gateway
  #     }
  #     vpn_connection = {
  #       local_ipv4_network_cidr    = "10.50.0.0/16" # Customer site
  #       remote_ipv4_network_cidr   = "10.20.0.0/16" # This VPC
  #       static_routes_only         = true
  #       static_routes_destinations = ["10.50.0.0/16"]
  #       route_table_keys           = ["networking-private", "networking-public"]
  #       tunnel1_preshared_key          = "12345678" # local.secrets.vpn_preshared_key
  #       tunnel1_cloudwatch_log_enabled = true
  #       tunnel2_preshared_key          = "12345678" # local.secrets.vpn_preshared_key
  #       tunnel2_cloudwatch_log_enabled = true
  #     }
  #     vpc_routes = {
  #       "networking" = {
  #         "private" = {
  #           destination_cidr_block = ["10.50.10.0/24", "10.50.11.0/24"]
  #         }
  #         "public" = {
  #           destination_cidr_block = ["10.50.10.0/24", "10.50.11.0/24"]
  #         }
  #       }
  #     }
  #   }
  #   "vpn-tgw" = {
  #     tgw = "tgw-01"
  #     # transit_gateway_id             = null
  #     # transit_gateway_route_table_id = null
  #     virtual_private_gateway = null
  #     customer_gateway = {
  #       ip_address = "222.222.101.101" # Public IP of the customer gateway
  #     }
  #     vpn_connection = {
  #       # Customer side 10.60.0.0/16. aws_vpn_connection allows one remote CIDR; 10.16.0.0/12 covers 10.20.0.0/16 and 10.30.0.0/16.
  #       local_ipv4_network_cidr        = "10.60.0.0/16"
  #       # remote_ipv4_network_cidr     = "10.16.0.0/12"
  #       static_routes_only             = true
  #       static_routes_destinations     = ["10.60.0.0/16"]
  #       route_table_keys               = []
  #       tunnel1_preshared_key          = "12345678" # local.secrets.vpn_preshared_key
  #       tunnel1_cloudwatch_log_enabled = true
  #       tunnel2_preshared_key          = "12345678" # local.secrets.vpn_preshared_key
  #       tunnel2_cloudwatch_log_enabled = true
  #     }
  #   }
  # }

  route53_parameters = {
    "${local.zone_public}" = {
      private = false
    }

    "${local.zone_private}" = {
      private = true
      vpc     = "networking"
    }
  }

  cloudmap_parameters = {
    "project1.${local.zone_internal}" = {
      vpc = "networking"
      # Or: vpc_id = "vpc-xxxxxxxxxxxxxx"
    }
    "project2.${local.zone_internal}" = {
      vpc = "networking"
    }
  }
}
