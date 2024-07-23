# Inherited variables

# Kasten variables

variable "k10_operator" {
  type = map(string)
  description = "Operator details of Kasten K10's installation"
}

variable "kubeconfig_location_relative_to_cwd" {
  type    = string
}