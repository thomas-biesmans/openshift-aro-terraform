resource "random_string" "randomsa" {
  length  = 6
  special = false
  upper   = false
  numeric = true
  lower   = true
}

resource "azurerm_storage_account" "sa" {
  name                            = format("%s%s", var.ownerref, random_string.randomsa.result)
  resource_group_name             = azurerm_resource_group.aro_rg.name
  location                        = azurerm_resource_group.aro_rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "sacontainer" {
  name                  = "k10"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}