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

variable "svp_sub2_client_id" {
  type        = string
  description = "ID for Service principal in subscription 2 for DNS"
}

variable "svp_sub2_client_secret" {
  type        = string
  description = "Secret for Service principal in subscription 2 for DNS"
}

variable "svp_sub2_tenant_id" {
  type        = string
  description = "Tenant ID for Service principal in subscription 2 for DNS"
}

variable "svp_sub2_subscription_id" {
  type        = string
  description = "Subscription ID for Service principal in subscription 2 for DNS"
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

variable "azure_dns_zone" {
  type = map(string)
}

# Lets Encrypt variables

variable "certmanager" {
  type        = map(string)
  description = "Cert manager instance details"
}

variable "kubeconfig_location_relative_to_cwd" {
  type = string
}

# OpenShift variables

variable "openshift" {
  type        = map(string)
  description = "OpenShift specifics"
}
