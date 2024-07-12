locals {
  aro_kubeconfig = yamldecode(module.aro[0].aro_kubeconfig_out)

  modified_clusters_yaml = [for cluster in local.aro_kubeconfig.clusters : merge(cluster, { cluster = merge(
    { insecure-skip-tls-verify = true },
    cluster.cluster
  ) })]

  modified_aro_kubeconfig = merge(
    local.aro_kubeconfig,
    { clusters = local.modified_clusters_yaml }
  )


  credentials_svp_sub1 = jsondecode(file("${path.module}/input-files/azurerm-creds/svp_sub1.cred"))
  credentials_svp_sub2 = jsondecode(file("${path.module}/input-files/azurerm-creds/svp_sub2.cred"))
}

# First subscription that hosts ARO
provider "azurerm" {
  features {}
  # alias           = "primary"
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


resource "local_file" "kubeconfig" {
  depends_on = [module.aro.aro_kubeconfig_out]
  filename   = var.kubeconfig_location
  content    = yamlencode(local.modified_aro_kubeconfig)
}


provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
  insecure    = true
}

provider "helm" {
  kubernetes {
    config_path = local_file.kubeconfig.filename
    insecure    = true
  }
}

# Deploying Azure Service Principals in our first subscription
module "azure_svp_sub1_creation" {
  count  = var.azure_svp_creation ? 1 : 0
  source = "./modules/00_service_principle_prep_sub1"

  providers = {
    azurerm = azurerm
    # azurerm = azurerm.primary
  }

  azlocation = var.azlocation
  ownerref   = var.ownerref
  owneremail = var.owneremail
  project    = var.project
  activity   = var.activity
}

# Deploying Azure Service Principals in our second subscription
module "azure_svp_sub2_creation" {
  count  = var.azure_svp_creation ? 1 : 0
  source = "./modules/00_service_principle_prep_sub2"

  providers = {
    azurerm = azurerm.secondary
  }

  azlocation = var.azlocation
  ownerref   = var.ownerref
  owneremail = var.owneremail
  project    = var.project
  activity   = var.activity
}

# Deploying Azure Red Hat OpenShift / ARO
module "aro" {
  source = "./modules/10_aro"

  providers = {
    azurerm = azurerm,
    # azurerm.primary   = azurerm.primary,
    azurerm.secondary = azurerm.secondary
  }

  azlocation = var.azlocation
  ownerref   = var.ownerref
  owneremail = var.owneremail
  project    = var.project
  activity   = var.activity

  svp_sub1_client_id     = local.credentials_svp_sub1.client_id
  svp_sub1_client_secret = local.credentials_svp_sub1.client_secret
}

# Deploying Kasten & a sample app to be backed up
module "kasten" {
  source = "./modules/20_kasten"

  azurerm_resource_group = module.aro[0].azurerm_resource_group_out
  aro_kubeconfig         = module.aro[0].aro_kubeconfig_out
  ownerref               = var.ownerref
  owneremail             = var.owneremail

  depends_on = [
    module.aro,
  ]
}