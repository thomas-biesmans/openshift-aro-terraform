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

variable "svp_sub1_client_id" {
  type        = string
  description = "ID for Service principal in subscription 1 for ARO"
}

variable "svp_sub1_client_secret" {
  type        = string
  description = "Secret for Service principal in subscription 1 for ARO"
}
variable "svp_sub1_tenant_id" {
  type        = string
  description = "Tenant ID for Service principal in subscription 1 for ARO"
}

# variable "svp_sub2_client_id" {
#   type        = string
#   description = "Service principal in subscription 2 for Azure DNS"
# }

locals {
  projectname = format("%s-%s", var.project, var.ownerref)
  domain      = format("%s%s", var.project, var.ownerref)
  tags = {
    owner    = var.owneremail
    activity = var.activity
    project  = var.project
  }
}

variable "azure_dns_zone" {
  type = map(string)
}

# OpenShift variables

variable "openshift" {
  type        = map(string)
  description = "OpenShift specifics"
}

variable "pull_secret_location_relative_to_root" {
  type = string
}

data "local_file" "pull_secret" {
  filename = "${path.root}${var.pull_secret_location_relative_to_root}"
}

variable "kubeconfig_location_relative_to_root" {
  type = string
}
