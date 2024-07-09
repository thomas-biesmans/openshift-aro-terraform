locals {
  aro_kubeconfig = yamldecode(module.aro.aro_kubeconfig_out)

  modified_clusters_yaml = [for cluster in local.aro_kubeconfig.clusters : merge(cluster, { cluster = merge(
    {insecure-skip-tls-verify = true},
    cluster.cluster
  )})]

  modified_aro_kubeconfig = merge(
    local.aro_kubeconfig,
    {clusters = local.modified_clusters_yaml}
  )
}

provider "azurerm" {
  features {}
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

# Deploying Azure Red Hat OpenShift / ARO
module "aro" {
  source = "./modules/00_aro"
}

# Deploying Kasten & a sample app to be backed up
module "kasten" {
  source = "./modules/10_kasten"

  azurerm_resource_group = module.aro.azurerm_resource_group_out
  aro_kubeconfig         = module.aro.aro_kubeconfig_out
  ownerref               = module.aro.ownerref_out
  owneremail             = module.aro.owneremail_out

  depends_on = [
    module.aro,
  ]
}