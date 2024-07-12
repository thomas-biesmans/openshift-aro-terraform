# Azure variables

variable "azure_dns_zone" {
  type = map(string)
  default = {
    name = "donisaurs.be" # Name of the DNS zone
    rg   = "DNS_RG"       # Resource Group name of the DNS zone
  }
}

# OpenShift variables

variable "openshift" {
  type = map(string)
  default = {
    version            = "4.14.16"         # Version running on the cluster, available versions found through 'az aro get-versions --location "westeurope\"'
    cluster_name       = "arotest"         # Cluster's name
    cluster_domain     = "donisaurs.be"    # Domain to be used for the cluster
    main_vm_size       = "Standard_D8s_v4" # CPU family for the control nodes, minimally Standard_D8s_v3
    worker_vm_size     = "Standard_D4s_v4" # CPU family for the worker nodes, minimally Standard_D4s_v3
    worker_disk_size   = 128               # Worker node disk size
    worker_node_count  = 3                 # Worker node count
    api_visibility     = "Public"          # Whether the API endpoint is publicly available
    ingress_visibility = "Public"          # Whether the ingress or *.apps endpoint is publicly available
  }
  description = "OpenShift specifics"
}

# required to get the operator to worker
# which is import for the kasten operator
# https://console.redhat.com/openshift/install/azure/aro-provisioned
variable "pull_secret_location" {
  type    = string
  default = "../../input-files/OpenShift-pull-secret/pull-secret.txt"
}

data "local_file" "pull_secret" {
  filename = "${path.module}/${var.pull_secret_location}"
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

variable "svp_sub1_client_id" {
  type        = string
  description = "ID for Service Principle in subscription 1 for ARO"
}

variable "svp_sub1_client_secret" {
  type        = string
  description = "Secret for Service Principle in subscription 1 for ARO"
}

# variable "svp_sub2_client_id" {
#   type        = string
#   description = "Service Principle in subscription 2 for Azure DNS"
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
