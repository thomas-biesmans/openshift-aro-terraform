
# Configuration parameters

variable "secret_location_dir_relative_to_cwd" {
  type    = string
  default = "./../input-files/azurerm-creds"
}

variable "config_location_dir_relative_to_cwd" {
  type    = string
  default = "./../input-files/azurerm-config"
}

variable "config_location_file_sub1" {
  type    = string
  default = "./sub1.yml"
}

variable "config_location_file_sub2" {
  type    = string
  default = "./sub2.yml"
}

variable "config_location_openshift_dir_relative_to_cwd" {
  type    = string
  default = "./../input-files/OpenShift-config"
}

variable "config_location_certmanager_file" {
  type    = string
  default = "./11_certmanager.yml"
}


locals {
  yaml_config_sub1 = yamldecode(file("${var.config_location_dir_relative_to_cwd}/${var.config_location_file_sub1}"))

  azlocation = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "azlocation", "") : var.azlocation
  ownerref   = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "ownerref", "") : var.ownerref
  owneremail = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "owneremail", "") : var.owneremail
  project    = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "project", "") : var.project
  activity   = local.yaml_config_sub1.azure != null ? lookup(local.yaml_config_sub1.azure, "activity", "") : var.activity

  openshift = local.yaml_config_sub1.openshift != null ? {
    version            = lookup(local.yaml_config_sub1.openshift, "version", "")
    cluster_name       = lookup(local.yaml_config_sub1.openshift, "cluster_name", "")
    cluster_domain     = lookup(local.yaml_config_sub1.openshift, "cluster_domain", "")
    main_vm_size       = lookup(local.yaml_config_sub1.openshift, "main_vm_size", "")
    worker_vm_size     = lookup(local.yaml_config_sub1.openshift, "worker_vm_size", "")
    worker_disk_size   = lookup(local.yaml_config_sub1.openshift, "worker_disk_size", "")
    worker_node_count  = lookup(local.yaml_config_sub1.openshift, "worker_node_count", "")
    api_visibility     = lookup(local.yaml_config_sub1.openshift, "api_visibility", "")
    ingress_visibility = lookup(local.yaml_config_sub1.openshift, "ingress_visibility", "")
    } : {
    version            = var.openshift["version"]
    cluster_name       = var.openshift["cluster_name"]
    cluster_domain     = var.openshift["cluster_domain"]
    main_vm_size       = var.openshift["main_vm_size"]
    worker_vm_size     = var.openshift["worker_vm_size"]
    worker_disk_size   = var.openshift["worker_disk_size"]
    worker_node_count  = var.openshift["worker_node_count"]
    api_visibility     = var.openshift["api_visibility"]
    ingress_visibility = var.openshift["ingress_visibility"]
  }


  yaml_config_sub2 = yamldecode(file("${var.config_location_dir_relative_to_cwd}/${var.config_location_file_sub2}"))

  azure_dns_zone = local.yaml_config_sub2.azure_dns != null ? {
    domain_name         = lookup(local.yaml_config_sub2.azure_dns, "domain_name", "")
    resource_group_name = lookup(local.yaml_config_sub2.azure_dns, "resource_group_name", "")
    ttl                 = lookup(local.yaml_config_sub2.azure_dns, "ttl", "")
    } : {
    domain_name         = var.azure_dns_zone["domain_name"]
    resource_group_name = var.azure_dns_zone["resource_group_name"]
    ttl                 = var.azure_dns_zone["ttl"]
  }


  yaml_config_certmanager = yamldecode(file("${var.config_location_openshift_dir_relative_to_cwd}/${var.config_location_certmanager_file}"))

  certmanager_operator = local.yaml_config_certmanager.certmanager.certmanager_operator != null ? {
    name                = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "name", "")
    namespace           = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "namespace", "")
    channel             = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "channel", "")
    installPlanApproval = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "installPlanApproval", "")
    source              = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "source", "")
    sourceNamespace     = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "sourceNamespace", "")
    startingCSV         = lookup(local.yaml_config_certmanager.certmanager.certmanager_operator, "startingCSV", "")
    } : {
    name                = var.certmanager_operator["name"]
    namespace           = var.certmanager_operator["namespace"]
    channel             = var.certmanager_operator["channel"]
    installPlanApproval = var.certmanager_operator["installPlanApproval"]
    source              = var.certmanager_operator["source"]
    sourceNamespace     = var.certmanager_operator["sourceNamespace"]
    startingCSV         = var.certmanager_operator["startingCSV"]
  }

  certmanager = local.yaml_config_certmanager.certmanager.certmanager != null ? {
    name                                                  = lookup(local.yaml_config_certmanager.certmanager.certmanager, "name", "")
    namespace                                             = lookup(local.yaml_config_certmanager.certmanager.certmanager, "namespace", "")
    letsencryptemail                                      = lookup(local.yaml_config_certmanager.certmanager.certmanager, "letsencryptemail", "")
    manual_refresh_api_certificate_trigger_timestamp      = lookup(local.yaml_config_certmanager.certmanager.certmanager, "manual_refresh_api_certificate_trigger_timestamp", "")
    manual_refresh_wildcard_certificate_trigger_timestamp = lookup(local.yaml_config_certmanager.certmanager.certmanager, "manual_refresh_wildcard_certificate_trigger_timestamp", "")
    } : {
    name                                                  = var.certmanager["name"]
    namespace                                             = var.certmanager["namespace"]
    letsencryptemail                                      = var.certmanager["letsencryptemail"]
    manual_refresh_api_certificate_trigger_timestamp      = var.certmanager["manual_refresh_api_certificate_trigger_timestamp"]
    manual_refresh_wildcard_certificate_trigger_timestamp = var.certmanager["manual_refresh_wildcard_certificate_trigger_timestamp"]
  }
}

variable "azlocation" {
  default     = "westeurope"
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  default     = "<abbreviated name>"
  description = "Owner of the project short name for naming resources or login"
}

variable "owneremail" {
  type        = string
  default     = "<email address>"
  description = "Owner of the project email"
}

variable "project" {
  type        = string
  default     = "<project name>"
  description = "project name"
}

variable "activity" {
  type        = string
  default     = "<activity tag, e.g. demo>"
  description = "activity"
}

variable "azure_dns_zone" {
  type = map(string)
  default = {
    domain_name         = "<domain name>"         # Name of the DNS zone
    resource_group_name = "<resource group name>" # Resource Group name of the DNS zone
    ttl                 = 300                     # TTL of the records, 300 by default
  }
}

# OpenShift variables

variable "openshift" {
  type = map(string)
  default = {
    version            = "4.14.16"                      # Version running on the cluster, available versions found through "az aro get-versions --location "westeurope\""
    cluster_name       = "<cluster name>"               # Cluster"s name
    cluster_domain     = "<domain name>"                # Domain to be used for the cluster
    main_vm_size       = "<size, e.g. Standard_D8s_v4>" # CPU family for the control nodes, minimally Standard_D8s_v3
    worker_vm_size     = "<size, e.g. Standard_D8s_v4>" # CPU family for the worker nodes, minimally Standard_D4s_v3
    worker_disk_size   = 128                            # Worker node disk size, e.g. 128
    worker_node_count  = 3                              # Worker node count, minimally 3
    api_visibility     = "<Private|Public>"             # Whether the API endpoint is publicly available
    ingress_visibility = "<Private|Public>"             # Whether the ingress or *.apps endpoint is publicly available
  }
  description = "OpenShift specifics"
}

variable "kubeconfig_location_relative_to_cwd" {
  type    = string
  default = "./../working-files/kubeconfig_aro.txt"
}


# Lets Encrypt variables

variable "certmanager" {
  type = map(string)
  default = {
    name                                                  = "certmanager"
    namespace                                             = "openshift-cert-manager"
    letsencryptemail                                      = "<email address configured for Lets Encrypt>"
    manual_refresh_api_certificate_trigger_timestamp      = "<timestamp string alphanumerically for manual triggers for the API cert, e.g. 'YYYY-MM-DD_hh-mm'>"
    manual_refresh_wildcard_certificate_trigger_timestamp = "<timestamp string alphanumerically for manual triggers for the wildcard cert, e.g. 'YYYY-MM-DD_hh-mm'>"
  }
  description = "Cert manager instance details"
}

variable "certmanager_operator" {
  type = map(string)
  default = {
    name                = "openshift-cert-manager-operator"
    namespace           = "openshift-cert-manager-operator"
    channel             = "stable-v1"
    installPlanApproval = "Automatic"
    source              = "redhat-operators"
    sourceNamespace     = "openshift-marketplace"
    # startingCSV         = "cert-manager-operator.v1.14.0"
  }
  description = "Operator details of Cert Manager's installation"
}
