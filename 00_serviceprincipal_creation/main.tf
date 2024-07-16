
# current subscription you're logged in with
provider "azurerm" {
  features {}
}

# Deploying Azure Service Principals in our first subscription

module "azure_serviceprincipal_prep_sub_aro" {
  source = "./modules/00_serviceprincipal_prep_sub_aro"

  providers = {
    azurerm = azurerm
  }

  azlocation                             = local.azlocation
  ownerref                               = local.ownerref
  owneremail                             = local.owneremail
  project                                = local.project
  activity                               = local.activity
  az_resource_providers                  = local.az_resource_providers
  secret_location_dir_relative_to_module = var.secret_location_dir_relative_to_module
}


# Deploying Azure Service Principals in our second subscription

module "azure_serviceprincipal_prep_sub_dns" {
  source = "./modules/00_serviceprincipal_prep_sub_dns"

  providers = {
    azurerm = azurerm
  }

  azlocation                             = local.azlocation
  ownerref                               = local.ownerref
  owneremail                             = local.owneremail
  project                                = local.project
  activity                               = local.activity
  secret_location_dir_relative_to_module = var.secret_location_dir_relative_to_module
}
