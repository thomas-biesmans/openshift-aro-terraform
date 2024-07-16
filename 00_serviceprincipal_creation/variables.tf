
# Configuration parameters

variable "azlocation" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  default     = "<abbreviated name>"
  description = "Owner of the project short name for naming resources or login"
}

variable "owneremail" {
  type        = string
  default     = "<email address>"
  description = "Owner of the project email"
}

variable "project" {
  type        = string
  default     = "<project name>"
  description = "project name"
}

variable "activity" {
  type        = string
  default     = "<activity tag, e.g. demo>"
  description = "activity"
}

variable "az_resource_providers" {
  type        = list(string)
  default     = ["Microsoft.RedHatOpenShift"]
  description = "Resource Providers that should be registered to a subscription"
}

variable "secret_location_dir_relative_to_module" {
  type    = string
  default = "./../../../input-files/azurerm-creds"
}

variable "config_location_dir_relative_to_cwd" {
  type    = string
  default = "./../input-files/azurerm-config"
}

variable "config_location_file_sub1" {
  type    = string
  default = "./sub1.yml"
}

locals {
  yaml_config_sub1 = yamldecode(file("${var.config_location_dir_relative_to_cwd}/${var.config_location_file_sub1}"))

  azlocation            = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "azlocation", "") : var.azlocation
  ownerref              = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "ownerref", "") : var.ownerref
  owneremail            = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "owneremail", "") : var.owneremail
  project               = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "project", "") : var.project
  activity              = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "activity", "") : var.activity
  az_resource_providers = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "az_resource_providers", "") : var.az_resource_providers

}
