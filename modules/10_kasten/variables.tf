variable "azurerm_resource_group" {
  type = object({
    name     = string
    location = string
    tags     = map(string)
  })
  description = "ARO resource group name"
}

variable "ownerref" {
  description = "Azure owner reference"
}
variable "owneremail" {
  description = "Azure owner email"
}
variable "aro_kubeconfig" {
  description = "ARO Kubeconfig information"
}

locals {
  aro_kubeconfig = yamldecode(var.aro_kubeconfig)
}

# Demo app variables

variable "initinsert" {
  type    = string
  default = "../../input-files/PostgreSQL-DB-fill/initinsert.psql"
}

data "local_file" "initinsert" {
  filename = "${path.module}/${var.initinsert}"
}


# Kasten variables

variable "azure_storage_account" {
  type = map(string)
  default = {
    tier             = "Standard"
    replication_type = "LRS"
  }
  description = "Account tier & replication type for the storage account used by Kasten, e.g. Standard & LRS"
}

variable "k10_namespace" {
  type        = string
  default     = "kasten-io"
  description = "Namespace where Kasten K10 should be installed, e.g. kasten-io"
}

variable "k10_operator" {
  type = map(string)
  default = {
    name                = "k10-kasten-operator-rhmp"
    namespace           = "kasten-io-operator"
    channel             = "stable"
    installPlanApproval = "Automatic"
    source              = "redhat-marketplace"
    sourceNamespace     = "openshift-marketplace"
    startingCSV         = "k10-kasten-operator-rhmp.v7.0.3"
  }
  description = "Namespace where Kasten K10's operator should be installed, e.g. kasten-io-operator"
}
