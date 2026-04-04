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


  vpn_parameters = {
    # "vpn-vpc-01" = {
    #   vpc = "networking" # Key into vpc_parameter (not vpc_name)
    #   virtual_private_gateway = {
    #     # virtual_private_gateway_id = null
    #   }
    #   customer_gateway = {
    #     ip_address = "123.123.123.123" // Required, Public IP of client VPN 
    #   }
    #   # Tunnel resource settings; if omitted, null/default values apply
    #   vpn_connection = {
    #     remote_ipv4_network_cidr = "10.30.0.0/16" // CIDR block shared from our VPC
    #     # If using static routing for specific machines, use
    #     static_routes_only         = true
    #     # static_routes_destinations = ["10.50.0.0/16", "10.51.0.0/16"]
    #     # route_table_names          = ["dmc-lv1-private", "dmc-lv1-public"]
    #     tunnel1_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel1_cloudwatch_log_enabled       = true
    #     tunnel2_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel2_cloudwatch_log_enabled       = true
    #   }
    # }

    # "vpn-tgw-01" = {
    #   # vpc = "networking" # Key into vpc_parameter (not vpc_name)
    #   transit_gateway_id = "tgw-0882eb490f1000e15"
    #   virtual_private_gateway = {
    #     # virtual_private_gateway_id = null
    #   }
    #   customer_gateway = {
    #     ip_address = "123.123.123.123" // Required, Public IP of client VPN 
    #   }
    #   # Tunnel resource settings; if omitted, null/default values apply
    #   vpn_connection = {
    #     remote_ipv4_network_cidr = "10.30.0.0/16" // CIDR block shared from our VPC
    #     # If using static routing for specific machines, use
    #     static_routes_only         = true
    #     # static_routes_destinations = ["10.50.0.0/16", "10.51.0.0/16"]
    #     # route_table_names          = ["dmc-lv1-private", "dmc-lv1-public"]
    #     tunnel1_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel1_cloudwatch_log_enabled       = true
    #     tunnel2_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel2_cloudwatch_log_enabled       = true
    #   }
    # }
    # "vpn-full" = {

    #   vpc = "networking" # Key into vpc_parameter (not vpc_name)
    #   # tgw = "tgw-01" # Key into tgw_parameter (not tgw_name)


    #   # Can be alternated between them if necessary
    #   # vpc_id = null
    #   # transit_gateway_id = "tgw-0882eb490f1000e15"

    #   # If resources already exist you can pass their ID; otherwise leave null and fill the rest for a custom configuration; if the object is null defaults apply
    #   # virtual_private_gateway = {
    #   #   # amazon_side_asn = 64512
    #   #   # availability_zone = null

    #   #   # virtual_private_gateway_id = null
    #   # }
    #   customer_gateway = {
    #     ip_address = "123.123.123.123" // Required, Public IP of client VPN 
    #     # device_name = null
    #     # bgp_asn = 65000
    #     # bgp_asn_extended = null
    #     # certificate_arn = null

    #     # customer_gateway_id = null
    #   }

    #   # Tunnel resource settings; if omitted, null/default values apply
    #   vpn_connection = {
    #     remote_ipv4_network_cidr = "10.30.0.0/16" // CIDR block shared from our VPC

    #     # If using static routing for specific machines, use
    #     static_routes_only         = true
    #     # static_routes_destinations = ["10.50.0.0/16", "10.51.0.0/16"]
    #     # route_table_names          = ["dmc-lv1-private", "dmc-lv1-public"]

    #     tunnel1_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel1_ike_versions                 = ["ikev2"]
    #     tunnel1_startup_action               = "start"
    #     tunnel1_dpd_timeout_action           = "none"
    #     tunnel1_phase1_dh_group_numbers      = ["14"]
    #     tunnel1_phase1_encryption_algorithms = ["AES128"]
    #     tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
    #     tunnel1_phase2_dh_group_numbers      = ["14"]
    #     tunnel1_phase2_encryption_algorithms = ["AES256"]
    #     tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
    #     tunnel1_cloudwatch_log_enabled       = true

    #     tunnel2_preshared_key                = "12345678" # local.secrets.vpn_preshared_key
    #     tunnel2_ike_versions                 = ["ikev2"]
    #     tunnel2_startup_action               = "start"
    #     tunnel2_dpd_timeout_action           = "none"
    #     tunnel2_phase1_dh_group_numbers      = ["14"]
    #     tunnel2_phase1_encryption_algorithms = ["AES128"]
    #     tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
    #     tunnel2_phase2_dh_group_numbers      = ["14"]
    #     tunnel2_phase2_encryption_algorithms = ["AES256"]
    #     tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
    #     tunnel2_cloudwatch_log_enabled       = true
    #   }

    #   # # Route propagation and route configuration when not using static routing only
    #   # vpc_routes = {
    #   #   "private" = {
    #   #     destination_cidr = ["172.0.10.1/24", "172.0.10.2/24"]
    #   #   }
    #   #   "public" = {
    #   #     destination_cidr = ["172.0.10.1/24", "172.0.10.2/24"]
    #   #   }
    #   # }
    # }
  }
}
