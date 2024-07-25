locals {
  kubeconfig_location_relative_to_cwd_insecure = replace(var.kubeconfig_location_relative_to_cwd, ".txt", "_insecure.txt")
  aro_kubeconfig                               = yamldecode(file("${local.kubeconfig_location_relative_to_cwd_insecure}"))

  credentials_svp_sub1_filename = "${var.secret_location_dir_relative_to_cwd}/svp_sub1.cred"
}

data "local_sensitive_file" "credentials_svp_sub1" {
  count    = fileexists(local.credentials_svp_sub1_filename) ? 1 : 0
  filename = local.credentials_svp_sub1_filename
}

locals {
  credentials_svp_sub1 = jsondecode(one(data.local_sensitive_file.credentials_svp_sub1[*].content))
}


# current subscription you're logged in with
provider "azurerm" {
  features {}
}

# First subscription that hosts ARO
provider "azurerm" {
  features {}
  alias           = "primary"
  client_id       = local.credentials_svp_sub1.client_id
  client_secret   = local.credentials_svp_sub1.client_secret
  tenant_id       = local.credentials_svp_sub1.tenant_id
  subscription_id = local.credentials_svp_sub1.subscription_id
}


provider "kubernetes" {
  config_path = local.kubeconfig_location_relative_to_cwd_insecure
  insecure    = true
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_location_relative_to_cwd_insecure
    insecure    = true
  }
}

# Deploying Kasten & a sample app to be backed up

module "kasten_crds" {
  source = "./modules/10_kasten_crds"

  k10_operator = local.k10_operator

  kubeconfig_location_relative_to_cwd = local.kubeconfig_location_relative_to_cwd_insecure

}
module "kasten_instance" {
  source = "./modules/11_kasten_instance"

  depends_on = [module.kasten_crds]

  owneremail = local.owneremail

  k10 = local.k10

  kubeconfig_location_relative_to_cwd = local.kubeconfig_location_relative_to_cwd_insecure

}
module "kasten" {
  source = "./modules/20_kasten"

  depends_on = [module.kasten_instance]

  azlocation = local.azlocation
  ownerref   = local.ownerref
  owneremail = local.owneremail
  project    = local.project
  activity   = local.activity

  azure_storage_account = local.azure_storage_account
  k10                   = local.k10

  kubeconfig_location_relative_to_cwd = local.kubeconfig_location_relative_to_cwd_insecure

}