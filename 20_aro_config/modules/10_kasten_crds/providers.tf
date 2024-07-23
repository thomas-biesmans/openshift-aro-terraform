terraform {
  required_version = ">=1.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.12"
    }
  }
}
