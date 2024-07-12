
variable "secret_location_dir" {
  type    = string
  default = "./input-files/azurerm-creds"
}

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

