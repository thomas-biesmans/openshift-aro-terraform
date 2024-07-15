locals {
  aro_kubeconfig = yamldecode(module.aro.aro_kubeconfig_out)

  modified_clusters_yaml = [for cluster in local.aro_kubeconfig.clusters : merge(cluster, { cluster = merge(
    { insecure-skip-tls-verify = true },
    cluster.cluster
  ) })]

  modified_aro_kubeconfig = merge(
    local.aro_kubeconfig,
    { clusters = local.modified_clusters_yaml }
  )

  credentials_svp_sub1_filename = "${path.module}/../input-files/azurerm-creds/svp_sub1.cred"
  credentials_svp_sub2_filename = "${path.module}/../input-files/azurerm-creds/svp_sub2.cred"

}

data "local_sensitive_file" "credentials_svp_sub1" {
  count    = fileexists(local.credentials_svp_sub1_filename) ? 1 : 0
  filename = local.credentials_svp_sub1_filename
}

data "local_sensitive_file" "credentials_svp_sub2" {
  count    = fileexists(local.credentials_svp_sub2_filename) ? 1 : 0
  filename = local.credentials_svp_sub2_filename
}

locals {
  credentials_svp_sub1 = jsondecode(one(data.local_sensitive_file.credentials_svp_sub1[*].content))
  credentials_svp_sub2 = jsondecode(one(data.local_sensitive_file.credentials_svp_sub2[*].content))
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

# Second subscription that hosts DNS zone
provider "azurerm" {
  features {}
  alias           = "secondary"
  client_id       = local.credentials_svp_sub2.client_id
  client_secret   = local.credentials_svp_sub2.client_secret
  tenant_id       = local.credentials_svp_sub2.tenant_id
  subscription_id = local.credentials_svp_sub2.subscription_id
}


# Deploying Azure Red Hat OpenShift / ARO

module "aro" {
  source = "./modules/10_aro"

  providers = {
    azurerm           = azurerm.primary,
    azurerm.secondary = azurerm.secondary
  }

  azlocation = local.azlocation
  ownerref   = local.ownerref
  owneremail = local.owneremail
  project    = local.project
  activity   = local.activity

  svp_sub1_client_id     = local.credentials_svp_sub1.client_id
  svp_sub1_client_secret = local.credentials_svp_sub1.client_secret
  svp_sub1_tenant_id     = local.credentials_svp_sub1.tenant_id

  azure_dns_zone = local.azure_dns_zone

  openshift = local.openshift

  pull_secret_location = var.pull_secret_location

}