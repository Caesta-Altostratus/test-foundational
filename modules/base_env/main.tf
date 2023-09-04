/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  base_project_id              = data.terraform_remote_state.environments_env.outputs.base_shared_vpc_project_id
  interconnect_project_number  = data.terraform_remote_state.org.outputs.interconnect_project_number
  dns_hub_project_id           = data.terraform_remote_state.org.outputs.dns_hub_project_id
  organization_service_account = data.terraform_remote_state.bootstrap.outputs.organization_step_terraform_service_account_email
  networks_service_account     = data.terraform_remote_state.bootstrap.outputs.networks_step_terraform_service_account_email
  projects_service_account     = data.terraform_remote_state.bootstrap.outputs.projects_step_terraform_service_account_email

  dedicated_interconnect_egress_policy = var.enable_dedicated_interconnect ? [
    {
      "from" = {
        "identity_type" = ""
        "identities"    = ["serviceAccount:${local.networks_service_account}"]
      },
      "to" = {
        "resources" = ["projects/${local.interconnect_project_number}"]
        "operations" = {
          "compute.googleapis.com" = {
            "methods" = ["*"]
          }
        }
      }
    },
  ] : []

  bgp_asn_number = var.enable_partner_interconnect ? "16550" : "64514"

}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/bootstrap/state"
  }
}

data "terraform_remote_state" "org" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/org/state"
  }
}

data "terraform_remote_state" "environments_env" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/environments/${var.env}"
  }
}

/******************************************
 Base shared VPC
*****************************************/

module "base_shared_vpc" {
  source = "../base_shared_vpc"

  project_id                 = local.base_project_id
  dns_hub_project_id         = local.dns_hub_project_id
  environment_code           = var.environment_code
  private_service_cidr       = var.base_private_service_cidr
  private_service_connect_ip = var.base_private_service_connect_ip
  default_region1            = var.default_region1
  default_region2            = var.default_region2
  domains                    = var.domains
  bgp_asn_subnet             = local.bgp_asn_number

  subnets = [
    {
      subnet_name           = "sb-${var.environment_code}-shared-base-${var.default_region1}"
      subnet_ip             = var.base_subnet_primary_ranges[var.default_region1]
      subnet_region         = var.default_region1
      subnet_private_access = "true"
      subnet_flow_logs      = true
      description           = "First ${var.env} subnet example."
    },
    {
      subnet_name           = "sb-${var.environment_code}-shared-base-${var.default_region2}"
      subnet_ip             = var.base_subnet_primary_ranges[var.default_region2]
      subnet_region         = var.default_region2
      subnet_private_access = "true"
      subnet_flow_logs      = true
      description           = "Second ${var.env} subnet example."
    }
  ]
  secondary_ranges = {
    "sb-${var.environment_code}-shared-base-${var.default_region1}" = var.base_subnet_secondary_ranges[var.default_region1]
  }
  allow_all_ingress_ranges = null
  allow_all_egress_ranges  = null
}
