variable "azlocation" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  default     = "ThBie"
  description = "Owner of the project short name for naming resources or login"
}

variable "owneremail" {
  type        = string
  default     = "thomas.biesmans@inetum-realdolmen.world"
  description = "Owner of the project email"
}

variable "project" {
  type        = string
  default     = "aro-kasten-test"
  description = "project name"
}

variable "activity" {
  type        = string
  default     = "demo"
  description = "activity"
}


# required to get the operator to worker
# which is import for the kasten operator
# https://console.redhat.com/openshift/install/azure/aro-provisioned
variable "pull_secret" {
  type    = string
  default = "pull-secret.txt" #../
}

data "local_file" "pull_secret" {
  filename = "${path.module}/${var.pull_secret}"
}

locals {
  projectname = format("%s-%s", var.ownerref, var.project)
  domain      = format("%s%s", var.ownerref, var.project)


  tags = {
    owner    = var.owneremail
    activity = var.activity
    project  = var.project
  }
}