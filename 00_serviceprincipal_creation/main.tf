locals {
  credentials_svp_sub1_filename = "${path.root}./input-files/azurerm-creds/svp_sub1.cred"
  credentials_svp_sub2_filename = "${path.root}./input-files/azurerm-creds/svp_sub2.cred"

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



# Deploying Azure Service Principals in our first subscription

module "azure_serviceprincipal_prep_sub_aro" {
  source = "./modules/00_serviceprincipal_prep_sub_aro"

  providers = {
    azurerm = azurerm
  }

  azlocation            = local.azlocation
  ownerref              = local.ownerref
  owneremail            = local.owneremail
  project               = local.project
  activity              = local.activity
  az_resource_providers = local.az_resource_providers
  secret_location_dir   = var.secret_location_dir
}


# Deploying Azure Service Principals in our second subscription

module "azure_serviceprincipal_prep_sub_dns" {
  source = "./modules/00_serviceprincipal_prep_sub_dns"

  providers = {
    azurerm = azurerm
  }

  azlocation          = local.azlocation
  ownerref            = local.ownerref
  owneremail          = local.owneremail
  project             = local.project
  activity            = local.activity
  secret_location_dir = var.secret_location_dir
}
