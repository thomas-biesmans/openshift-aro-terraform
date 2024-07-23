# Inherited variables

variable "owneremail" {
  type        = string
  description = "Owner of the project email"
}

# Kasten variables

variable "k10" {
  type        = map(string)
  description = "Kasten K10 instance details"
}

variable "kubeconfig_location_relative_to_cwd" {
  type = string
}