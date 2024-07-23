# Inherited variables

variable "azlocation" {
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  description = "Owner of the project short name for naming resources or login"
}

variable "owneremail" {
  type        = string
  description = "Owner of the project email"
}

variable "project" {
  type        = string
  description = "project name"
}

variable "activity" {
  type        = string
  description = "activity"
}

locals {
  projectname = format("%s-%s", var.project, var.ownerref)
  domain      = format("%s%s", var.project, var.ownerref)
  tags = {
    owner    = var.owneremail
    activity = var.activity
    project  = var.project
  }
}


# Demo app variables

variable "postgresql_initinsert_psql" {
  type = string
}

data "local_file" "initinsert" {
  filename = "${path.module}/${var.postgresql_initinsert_psql}"
}


# Kasten variables

variable "azure_storage_account" {
  type        = map(string)
  description = "Account tier & replication type for the storage account used by Kasten, e.g. Standard & LRS"
}

variable "k10" {
  type        = map(string)
  description = "Kasten K10 instance details"
}

variable "kubeconfig_location_relative_to_cwd" {
  type = string
}