terraform {
  required_version = ">=1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.27"   
    }
  }
}

data "terraform_remote_state" "aro" {
  backend = "local"

  config = {
    path = "../terraform.tfstate"
  }
}

locals {
  aro_kubeconfig = yamldecode(data.terraform_remote_state.aro.outputs.aro_kubeconfig_out)
}

provider "kubernetes" {
    host                   = local.aro_kubeconfig.clusters[0].cluster.server
    client_certificate     = base64decode(local.aro_kubeconfig.users[0].user.client-certificate-data)
    client_key             = base64decode(local.aro_kubeconfig.users[0].user.client-key-data)
    cluster_ca_certificate = ""
}
