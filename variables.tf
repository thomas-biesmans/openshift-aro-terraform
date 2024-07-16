
# Switches

variable "azure_svp_creation" {
  type        = bool
  default     = false
  description = "Needed when configuring the Service Principals in any of the subscriptions"
}


# Configration parameters

variable "azlocation" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  default     = "thbie"
  description = "Owner of the project short name for naming resources or login"
}

variable "owneremail" {
  type        = string
  default     = "thomas.biesmans@inetum-realdolmen.world"
  description = "Owner of the project email"
}

variable "project" {
  type        = string
  default     = "az-we-lab-aro-kasten"
  description = "project name"
}

variable "activity" {
  type        = string
  default     = "demo"
  description = "activity"
}


# Internal variables

