terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~>3.0"
      configuration_aliases = [azurerm, azurerm.secondary]
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.13"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}