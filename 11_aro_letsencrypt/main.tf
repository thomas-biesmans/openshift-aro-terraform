locals {
  kubeconfig_location_relative_to_cwd_insecure = replace(var.kubeconfig_location_relative_to_cwd, ".txt", "_insecure.txt")
  aro_kubeconfig                               = yamldecode(file("${local.kubeconfig_location_relative_to_cwd_insecure}"))

  credentials_svp_sub2_filename = "${var.secret_location_dir_relative_to_cwd}/svp_sub2.cred"
}

data "local_sensitive_file" "credentials_svp_sub2" {
  count    = fileexists(local.credentials_svp_sub2_filename) ? 1 : 0
  filename = local.credentials_svp_sub2_filename
}

locals {
  credentials_svp_sub2 = jsondecode(one(data.local_sensitive_file.credentials_svp_sub2[*].content))
}


# current subscription you're logged in with
provider "azurerm" {
  features {}
}

# First subscription that hosts DNS
provider "azurerm" {
  features {}
  alias           = "secondary"
  client_id       = local.credentials_svp_sub2.client_id
  client_secret   = local.credentials_svp_sub2.client_secret
  tenant_id       = local.credentials_svp_sub2.tenant_id
  subscription_id = local.credentials_svp_sub2.subscription_id
}


provider "kubernetes" {
  config_path = local.kubeconfig_location_relative_to_cwd_insecure
  insecure    = true
}


# Deploying Lets Encrypt

module "letsencrypt_crds" {
  source = "./modules/10_letsencrypt_crds"

  certmanager_operator = local.certmanager_operator

  kubeconfig_location_relative_to_cwd = local.kubeconfig_location_relative_to_cwd_insecure

}
module "letsencrypt" {
  source = "./modules/20_letsencrypt"

  depends_on = [module.letsencrypt_crds]

  providers = {
    azurerm = azurerm.secondary
  }

  azlocation = local.azlocation
  ownerref   = local.ownerref
  owneremail = local.owneremail
  project    = local.project
  activity   = local.activity

  svp_sub2_client_id       = local.credentials_svp_sub2.client_id
  svp_sub2_client_secret   = local.credentials_svp_sub2.client_secret
  svp_sub2_tenant_id       = local.credentials_svp_sub2.tenant_id
  svp_sub2_subscription_id = local.credentials_svp_sub2.subscription_id

  azure_dns_zone = local.azure_dns_zone

  openshift = local.openshift
  
  certmanager = local.certmanager

  kubeconfig_location_relative_to_cwd = local.kubeconfig_location_relative_to_cwd_insecure

}